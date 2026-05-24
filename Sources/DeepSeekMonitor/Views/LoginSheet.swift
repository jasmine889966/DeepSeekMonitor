import SwiftUI
import WebKit
import os

struct LoginSheet: View {
    let l10n: L10n
    @Environment(\.dismiss) private var dismiss
    @State private var status: String
    @State private var isCapturing = false
    @State private var captureRequest = 0
    @State private var nonce = UUID().uuidString
    @State private var did = UserDefaults.standard.string(forKey: "deepseek.device-id") ?? UUID().uuidString

    var onSession: (DeepSeekSession) async -> Void

    init(l10n: L10n, onSession: @escaping (DeepSeekSession) async -> Void) {
        self.l10n = l10n
        self.onSession = onSession
        _status = State(initialValue: l10n.captureTokenHint)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.tokenCaptureTitle)
                        .font(.headline)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button(l10n.cancel) {
                    dismiss()
                }
                Button {
                    MonitorLogger.login.info("capture button tapped")
                    MonitorLogger.file("login", "capture button tapped")
                    status = l10n.requestCurrentUser
                    isCapturing = true
                    captureRequest += 1
                    nonce = UUID().uuidString
                } label: {
                    if isCapturing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(l10n.captureToken, systemImage: "key")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(.bar)

            WebLoginView(
                l10n: l10n,
                status: $status,
                isCapturing: $isCapturing,
                captureRequest: captureRequest,
                nonce: nonce,
                did: did,
                acceptLanguage: l10n.language.isChinese ? "zh-CN,zh-Hans;q=0.9" : "en-US,en;q=0.9",
                onSession: onSession
            )
        }
    }
}

struct WebLoginView: NSViewRepresentable {
    let l10n: L10n
    @Binding var status: String
    @Binding var isCapturing: Bool
    var captureRequest: Int
    var nonce: String
    var did: String
    var acceptLanguage: String
    var onSession: (DeepSeekSession) async -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            status: $status,
            isCapturing: $isCapturing,
            onSession: onSession,
            nonce: nonce,
            did: did,
            acceptLanguage: acceptLanguage,
            l10n: l10n
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController.add(context.coordinator, contentWorld: .page, name: "deepseekToken")
        let captureScript = WKUserScript(
            source: Self.captureHookScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .page
        )
        configuration.userContentController.addUserScript(captureScript)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.load(URLRequest(url: URL(string: "https://platform.deepseek.com/usage")!))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.updateNonce(nonce)
        context.coordinator.updateDid(did)
        context.coordinator.captureIfNeeded(captureRequest)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var status: String
        @Binding var isCapturing: Bool
        var onSession: (DeepSeekSession) async -> Void
        weak var webView: WKWebView?
        private var lastCaptureRequest = 0
        private var nonce: String
        private var did: String
        private var acceptLanguage: String
        private let l10n: L10n

        init(
            status: Binding<String>,
            isCapturing: Binding<Bool>,
            onSession: @escaping (DeepSeekSession) async -> Void,
            nonce: String,
            did: String,
            acceptLanguage: String,
            l10n: L10n
        ) {
            _status = status
            _isCapturing = isCapturing
            self.onSession = onSession
            self.nonce = nonce
            self.did = did
            self.acceptLanguage = acceptLanguage
            self.l10n = l10n
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MonitorLogger.login.info("webview finished url=\(webView.url?.absoluteString ?? "", privacy: .public)")
            MonitorLogger.file("login", "webview finished url=\(webView.url?.absoluteString ?? "")")
            status = webView.url?.host == "platform.deepseek.com"
                ? l10n.captureReady
                : l10n.captureWaiting
        }

        func captureIfNeeded(_ request: Int) {
            guard request != lastCaptureRequest else { return }
            lastCaptureRequest = request
            MonitorLogger.login.info("capture requested nonce=\(self.nonce, privacy: .public)")
            MonitorLogger.file("login", "capture requested")
            beginCaptureCycle()
        }

        func updateNonce(_ nonce: String) {
            self.nonce = nonce
        }

        func updateDid(_ did: String) {
            self.did = did
        }

        private func beginCaptureCycle() {
            guard let webView else { return }
            isCapturing = true
            status = l10n.requestCurrentUser
            MonitorLogger.login.info("begin capture cycle url=\(webView.url?.absoluteString ?? "", privacy: .public)")
            MonitorLogger.file("login", "begin capture cycle url=\(webView.url?.absoluteString ?? "")")
            let markerScript = """
            try {
              localStorage.setItem('__deepseek_monitor_capture_nonce', '\(nonce)');
              sessionStorage.setItem('__deepseek_monitor_capture_nonce', '\(nonce)');
            } catch (error) {}
            """
            webView.evaluateJavaScript(markerScript, in: nil, in: .page, completionHandler: nil)
            webView.evaluateJavaScript(Self.activeCaptureScript(nonce: nonce), in: nil, in: .page) { result in
                if case .failure(let error) = result {
                    MonitorLogger.login.error("active capture script failed: \(error.localizedDescription, privacy: .public)")
                    MonitorLogger.file("login", "active capture script failed: \(error.localizedDescription)")
                }
            }
            webView.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if self.isCapturing {
                    self.status = self.l10n.captureFailed("no token event received")
                    self.isCapturing = false
                    MonitorLogger.login.error("capture timeout waiting for token event")
                    MonitorLogger.file("login", "capture timeout waiting for token event")
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "deepseekToken" else { return }
            guard let body = message.body as? [String: Any] else {
                status = l10n.captureFailed("invalid message")
                isCapturing = false
                MonitorLogger.login.error("invalid message body")
                MonitorLogger.file("login", "invalid message body")
                return
            }
            guard let messageNonce = body["nonce"] as? String, messageNonce == nonce else { return }
            if let error = body["error"] as? String, !error.isEmpty {
                let source = body["source"] as? String
                status = l10n.captureFailed(source.map { "\($0): \(error)" } ?? error)
                isCapturing = false
                MonitorLogger.login.error("capture error source=\(body["source"] as? String ?? "", privacy: .public) error=\(error, privacy: .public)")
                MonitorLogger.file("login", "capture error source=\(body["source"] as? String ?? "") error=\(error)")
                return
            }
            guard let token = body["token"] as? String, !token.isEmpty else {
                status = l10n.captureFailed("token was empty.")
                isCapturing = false
                MonitorLogger.login.error("token empty in capture message")
                MonitorLogger.file("login", "token empty in capture message")
                return
            }
            if let source = body["source"] as? String {
                status = l10n.saveLoginSuccess + " (\(source))"
            } else {
                status = l10n.saveLoginSuccess
            }
            MonitorLogger.login.info("token captured source=\(body["source"] as? String ?? "", privacy: .public)")
            MonitorLogger.file("login", "token captured source=\(body["source"] as? String ?? "")")
            guard let webView else {
                status = l10n.captureFailed("webView missing")
                isCapturing = false
                MonitorLogger.login.error("webview missing after token capture")
                MonitorLogger.file("login", "webview missing after token capture")
                return
            }
            validateSession(using: webView, token: token)
        }

        private func validateSession(using webView: WKWebView, token: String) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let platformCookies = cookies.filter { $0.domain.contains("deepseek.com") }
                let cookieHeader = Self.cookieHeader(from: platformCookies)
                MonitorLogger.login.info("validate session with cookies=\(platformCookies.count)")
                MonitorLogger.file("login", "validate session with cookies=\(platformCookies.count)")
                let session = DeepSeekSession(
                    token: token,
                    cookieHeader: cookieHeader,
                    appVersion: "1.0.0",
                    acceptLanguage: self.acceptLanguage,
                    did: self.did
                )
                Task { @MainActor in
                    self.isCapturing = false
                    self.clearCaptureMarkers(in: webView)
                    await self.onSession(session)
                }
            }
        }

        private func clearCaptureMarkers(in webView: WKWebView) {
            let script = """
            try {
              localStorage.removeItem('__deepseek_monitor_capture_nonce');
              sessionStorage.removeItem('__deepseek_monitor_capture_nonce');
            } catch (error) {}
            """
            webView.evaluateJavaScript(script, in: nil, in: .page, completionHandler: nil)
        }

        private static func cookieHeader(from cookies: [HTTPCookie]) -> String {
            if cookies.isEmpty { return "" }
            if let header = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"], !header.isEmpty {
                return header
            }
            return cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        }

        private static func activeCaptureScript(nonce: String) -> String {
            """
            (() => {
              const nonce = '\(nonce)';
              const post = payload => {
                try {
                  window.webkit.messageHandlers.deepseekToken.postMessage(payload);
                } catch {}
              };
              const tokenPattern = /(?:Bearer\\s+)?([A-Za-z0-9+/._~-]{40,}={0,2})/g;
              const reject = value => {
                const lower = String(value || '').toLowerCase();
                return lower.includes('webpack')
                  || lower.includes('platform.deepseek.com')
                  || lower.includes('static.deepseek.com')
                  || lower.includes('chunk')
                  || lower.includes('sourcemap')
                  || lower.includes('smid')
                  || lower.includes('hwwaf')
                  || lower.includes('thumbcache');
              };
              const emitCandidate = (value, source) => {
                if (!/token|auth|bearer|current|user|session/i.test(source)) return false;
                if (typeof value !== 'string' || reject(value)) return false;
                let match;
                tokenPattern.lastIndex = 0;
                while ((match = tokenPattern.exec(value)) !== null) {
                  const token = match[1] || match[0];
                  if (token.length >= 40 && token.length <= 256) {
                    post({ nonce, token, source, detail: 'active-scan' });
                    return true;
                  }
                }
                return false;
              };
              const scanObject = (value, source, depth = 0, seen = new Set()) => {
                if (depth > 3 || value == null) return false;
                if (typeof value === 'string') return emitCandidate(value, source);
                if (typeof value !== 'object' && typeof value !== 'function') return false;
                if (seen.has(value)) return false;
                seen.add(value);
                try {
                  if (Array.isArray(value)) {
                    for (const item of value.slice(0, 50)) {
                      if (scanObject(item, source, depth + 1, seen)) return true;
                    }
                    return false;
                  }
                  const keys = Object.keys(value).slice(0, 80);
                  const priority = keys.filter(key => /token|auth|session|user|bearer/i.test(key));
                  for (const key of [...priority, ...keys]) {
                    try {
                      if (emitCandidate(key, `${source}.${key}`)) return true;
                      if (scanObject(value[key], `${source}.${key}`, depth + 1, seen)) return true;
                    } catch {}
                  }
                } catch {}
                return false;
              };
              const scanStorage = (storage, source) => {
                try {
                  for (let index = 0; index < storage.length; index += 1) {
                    const key = storage.key(index);
                    const value = storage.getItem(key);
                    if (!/token|auth|bearer|current|user|session/i.test(key || '')) continue;
                    if (emitCandidate(key, `${source}.${key}`)) return true;
                    if (emitCandidate(value, `${source}.${key}`)) return true;
                    try {
                      if (scanObject(JSON.parse(value), `${source}.${key}`)) return true;
                    } catch {}
                  }
                } catch {}
                return false;
              };
              const readCurrentUser = async () => {
                try {
                  if (!activeNonce()) return;
                  const response = await fetch('/auth-api/v0/users/current', {
                    method: 'GET',
                    credentials: 'include',
                    cache: 'no-store',
                    headers: { 'Accept': '*/*', 'x-app-version': '1.0.0' }
                  });
                  const text = await response.text();
                  let payload = null;
                  try { payload = JSON.parse(text); } catch {}
                  const token = payload?.data?.biz_data?.token
                    || payload?.data?.bizData?.token
                    || payload?.data?.token
                    || payload?.token;
                  if (!activeNonce()) return;
                  if (typeof token === 'string' && token.length > 20) {
                    post({ nonce, token, source: 'current-user-response', detail: 'active-fetch' });
                  } else {
                    post({
                      nonce,
                      error: `current-user token missing; status=${response.status}; body=${text.slice(0, 300)}`,
                      source: 'current-user-response'
                    });
                  }
                } catch (error) {
                  if (!activeNonce()) return;
                  post({
                    nonce,
                    error: error && error.message ? error.message : String(error),
                    source: 'current-user-request'
                  });
                }
              };
              readCurrentUser();
              if (scanStorage(localStorage, 'localStorage')) return;
              if (scanStorage(sessionStorage, 'sessionStorage')) return;
              const globalKeys = Object.keys(window).filter(key => /deep|seek|auth|token|user|session|store|redux|zustand|pinia/i.test(key));
              for (const key of globalKeys.slice(0, 120)) {
                try {
                  if (scanObject(window[key], `window.${key}`)) return;
                } catch {}
              }
              post({ nonce, error: 'no token candidate in page storage.', source: 'active-scan' });
            })();
            """
        }
    }

    private static let captureHookScript = #"""
    (() => {
      const captureKey = '__deepseek_monitor_capture_nonce';
      const messageName = 'deepseekToken';
      const deepSeekPattern = /(?:platform\.deepseek\.com)?\/(auth-api\/v0\/users\/current|api\/v0\/users\/get_user_summary|api\/v0\/usage\/amount|api\/v0\/usage\/cost|api\/v0\/client\/settings)/;

      const post = payload => {
        try {
          window.webkit.messageHandlers[messageName].postMessage(payload);
        } catch {}
      };

      const normalizeToken = value => {
        if (typeof value !== 'string') return null;
        const trimmed = value.trim();
        if (!trimmed) return null;
        if (/^Bearer\s+[A-Za-z0-9+/._~-]{20,}={0,2}$/.test(trimmed)) {
          return trimmed.replace(/^Bearer\s+/, '');
        }
        if (/^[A-Za-z0-9+/._~-]{20,}={0,2}$/.test(trimmed)) {
          return trimmed;
        }
        return null;
      };

      const activeNonce = () => {
        try {
          return localStorage.getItem(captureKey) || sessionStorage.getItem(captureKey) || '';
        } catch {
          return '';
        }
      };

      const emitIfNeeded = (token, source, detail) => {
        const nonce = activeNonce();
        if (!nonce) return;
        const normalized = normalizeToken(token);
        if (!normalized) return;
        post({
          nonce,
          token: normalized,
          source,
          detail
        });
      };

      const headerValue = (headers, name) => {
        if (!headers) return null;
        try {
          if (headers instanceof Headers) {
            return headers.get(name);
          }
        } catch {}
        try {
          if (Array.isArray(headers)) {
            const match = headers.find(([key]) => String(key).toLowerCase() === name.toLowerCase());
            return match ? match[1] : null;
          }
        } catch {}
        try {
          if (typeof headers === 'object') {
            const keys = Object.keys(headers);
            const match = keys.find(key => key.toLowerCase() === name.toLowerCase());
            return match ? headers[match] : null;
          }
        } catch {}
        return null;
      };

            const requestUrl = (input, init) => {
                try {
          if (typeof input === 'string') return new URL(input, window.location.href).href;
          if (input && typeof input.url === 'string') return new URL(input.url, window.location.href).href;
        } catch {}
        try {
          if (input instanceof Request) return new URL(input.url, window.location.href).href;
        } catch {}
        try {
          return input ? new URL(String(input), window.location.href).href : '';
        } catch {
          return '';
        }
      };

      const requestAuth = (input, init) => {
        try {
          if (init && init.headers) {
            const value = headerValue(init.headers, 'Authorization');
            if (value) return value;
          }
        } catch {}
        try {
          if (input instanceof Request) {
            const value = headerValue(input.headers, 'Authorization');
            if (value) return value;
          }
        } catch {}
        return null;
      };

      if (!window.__deepseekMonitorFetchPatched) {
        window.__deepseekMonitorFetchPatched = true;
        const originalFetch = window.fetch.bind(window);
        window.fetch = function(input, init) {
          try {
            const url = requestUrl(input, init);
            if (deepSeekPattern.test(url)) {
              emitIfNeeded(requestAuth(input, init), 'fetch', url);
            }
          } catch {}
          return originalFetch(input, init);
        };
      }

      if (!window.__deepseekMonitorXhrPatched) {
        window.__deepseekMonitorXhrPatched = true;
        const open = XMLHttpRequest.prototype.open;
        const send = XMLHttpRequest.prototype.send;
        const setRequestHeader = XMLHttpRequest.prototype.setRequestHeader;
        XMLHttpRequest.prototype.open = function(method, url) {
          this.__deepseekMonitorUrl = String(url || '');
          this.__deepseekMonitorHeaders = {};
          return open.apply(this, arguments);
        };
        XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
          try {
            this.__deepseekMonitorHeaders = this.__deepseekMonitorHeaders || {};
            this.__deepseekMonitorHeaders[String(name).toLowerCase()] = String(value);
          } catch {}
          return setRequestHeader.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function(body) {
          try {
            const url = new URL(this.__deepseekMonitorUrl || '', window.location.href).href;
            if (deepSeekPattern.test(url)) {
              const auth = this.__deepseekMonitorHeaders?.authorization || null;
              emitIfNeeded(auth, 'xhr', url);
            }
          } catch {}
          return send.apply(this, arguments);
        };
      }
    })();
    """#
}
