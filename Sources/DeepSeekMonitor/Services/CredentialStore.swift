import Foundation

protocol CredentialStoring: Sendable {
    func loadToken() throws -> String?
    func loadCookieHeader() throws -> String?
    func saveToken(_ token: String) throws
    func saveCookieHeader(_ cookieHeader: String) throws
    func deleteToken() throws
    func deleteCookieHeader() throws
}

enum CredentialStoreError: LocalizedError {
    case storageFailure(String)

    var errorDescription: String? {
        switch self {
        case .storageFailure(let message):
            message
        }
    }
}

struct CredentialStore: CredentialStoring {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.deepseek.monitor.credentials")

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    func loadToken() throws -> String? {
        try load().token
    }

    func loadCookieHeader() throws -> String? {
        try load().cookieHeader
    }

    func saveToken(_ token: String) throws {
        var state = try load()
        state.token = token
        try save(state)
    }

    func saveCookieHeader(_ cookieHeader: String) throws {
        var state = try load()
        state.cookieHeader = cookieHeader
        try save(state)
    }

    func deleteToken() throws {
        var state = try load()
        state.token = nil
        try save(state)
    }

    func deleteCookieHeader() throws {
        var state = try load()
        state.cookieHeader = nil
        try save(state)
    }

    private func load() throws -> StoredCredentials {
        try queue.sync {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return StoredCredentials()
            }
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(StoredCredentials.self, from: data)
        }
    }

    private func save(_ credentials: StoredCredentials) throws {
        try queue.sync {
            let folderURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let data = try encoder.encode(credentials)
            try data.write(to: fileURL, options: [.atomic])
        }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("DeepSeekMonitor", isDirectory: true)
            .appendingPathComponent("credentials.json", isDirectory: false)
    }
}

struct StoredCredentials: Codable, Sendable {
    var token: String?
    var cookieHeader: String?
}

struct InMemoryCredentialStore: CredentialStoring {
    final class Box: @unchecked Sendable {
        var token: String?
        var cookieHeader: String?
    }

    let box: Box

    init(token: String? = nil) {
        box = Box()
        box.token = token
    }

    func loadToken() throws -> String? {
        box.token
    }

    func loadCookieHeader() throws -> String? {
        box.cookieHeader
    }

    func saveToken(_ token: String) throws {
        box.token = token
    }

    func saveCookieHeader(_ cookieHeader: String) throws {
        box.cookieHeader = cookieHeader
    }

    func deleteToken() throws {
        box.token = nil
    }

    func deleteCookieHeader() throws {
        box.cookieHeader = nil
    }
}
