import Foundation

protocol OfficialStatusFetching: Sendable {
    func fetchStatus() async throws -> OfficialServiceStatus
}

enum OfficialStatusError: LocalizedError, Equatable {
    case missingHTML
    case noComponents

    var errorDescription: String? {
        switch self {
        case .missingHTML: "DeepSeek status page returned an empty response."
        case .noComponents: "DeepSeek status page did not include component status."
        }
    }
}

struct OfficialStatusClient: OfficialStatusFetching {
    var statusURL = OfficialServiceStatus.sourceURL
    var atomURL = URL(string: "https://status.deepseek.com/history.atom")!
    var urlSession: URLSession = .shared
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar
    }()

    func fetchStatus() async throws -> OfficialServiceStatus {
        async let htmlData = data(from: statusURL)
        async let atomData = data(from: atomURL)

        let html = String(data: try await htmlData, encoding: .utf8) ?? ""
        guard !html.isEmpty else { throw OfficialStatusError.missingHTML }

        let incidents: [ServiceIncident]
        do {
            incidents = try OfficialStatusParser.parseAtom(data: try await atomData)
        } catch {
            incidents = []
        }

        return try OfficialStatusParser.parseStatusPage(
            html: html,
            incidents: incidents,
            sourceURL: statusURL,
            refreshedAt: Date(),
            calendar: calendar
        )
    }

    private func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("DeepSeekMonitor/1.2.1", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DeepSeekClientError.unexpectedStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }
}

enum OfficialStatusParser {
    static func parseStatusPage(
        html: String,
        incidents: [ServiceIncident],
        sourceURL: URL = OfficialServiceStatus.sourceURL,
        refreshedAt: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) throws -> OfficialServiceStatus {
        let components = parseComponents(html: html, calendar: calendar)
        guard !components.isEmpty else { throw OfficialStatusError.noComponents }
        let summary = components.map(\.currentHealth).max { $0.severity < $1.severity } ?? .unknown
        let summaryTitle = textBetween(html, start: "<h2", end: "</h2>")
            .flatMap { textAfterFirstTag($0) }
            ?? summary.title(language: .english)
        let summaryDetail = textBetween(html, start: "<p class=\"text-sm text-muted-foreground mt-1 ml-6\">", end: "</p>") ?? ""

        return OfficialServiceStatus(
            summary: summary,
            summaryTitle: cleanHTML(summaryTitle),
            summaryDetail: cleanHTML(summaryDetail),
            components: components,
            incidents: incidents.sorted { $0.updatedAt > $1.updatedAt },
            sourceURL: sourceURL,
            refreshedAt: refreshedAt
        )
    }

    static func parseAtom(data: Data) throws -> [ServiceIncident] {
        let parser = AtomIncidentParser(data: data)
        return try parser.parse()
    }

    private static func parseComponents(html: String, calendar: Calendar) -> [ServiceComponentStatus] {
        let names = [
            "API 服务 (API Service)",
            "网页对话服务 (Web Chat Service)"
        ]

        return names.compactMap { name in
            guard let start = html.range(of: name) else { return nil }
            let tail = html[start.lowerBound...]
            let nextComponent = names
                .filter { $0 != name }
                .compactMap { tail.range(of: $0)?.lowerBound }
                .min()
            let end = nextComponent ?? tail.endIndex
            let block = String(tail[..<end])
            let uptime = firstMatch(in: block, pattern: #"([0-9]+(?:\.[0-9]+)?% uptime)"#) ?? ""
            let colors = allMatches(in: block, pattern: #"fill="(#[0-9a-fA-F]{6})""#)
                .prefix(90)
                .map(ServiceHealth.init(colorHex:))
            guard !colors.isEmpty else { return nil }
            let days = makeDays(healths: Array(colors), calendar: calendar)
            let currentHealth = days.last?.health ?? .unknown
            return ServiceComponentStatus(
                name: cleanHTML(name),
                uptime: uptime,
                currentHealth: currentHealth,
                days: days
            )
        }
    }

    private static func makeDays(healths: [ServiceHealth], calendar: Calendar) -> [ServiceStatusDay] {
        let today = calendar.startOfDay(for: Date())
        let startOffset = healths.count - 1
        return healths.enumerated().compactMap { index, health in
            guard let date = calendar.date(byAdding: .day, value: index - startOffset, to: today) else {
                return nil
            }
            return ServiceStatusDay(date: date, health: health)
        }
    }

    private static func textBetween(_ text: String, start: String, end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text[startRange.upperBound...].range(of: end) else {
            return nil
        }
        return String(text[startRange.upperBound..<endRange.lowerBound])
    }

    private static func textAfterFirstTag(_ text: String) -> String? {
        guard let range = text.range(of: ">") else { return nil }
        return String(text[range.upperBound...])
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        allMatches(in: text, pattern: pattern).first
    }

    private static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            let rangeIndex = match.numberOfRanges > 1 ? 1 : 0
            guard let range = Range(match.range(at: rangeIndex), in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func cleanHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"&amp;"#, with: "&")
            .replacingOccurrences(of: #"&#x27;"#, with: "'")
            .replacingOccurrences(of: #"&quot;"#, with: "\"")
            .replacingOccurrences(of: #"&lt;"#, with: "<")
            .replacingOccurrences(of: #"&gt;"#, with: ">")
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class AtomIncidentParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private var incidents: [ServiceIncident] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentID = ""
    private var currentLink = ""
    private var currentSummary = ""
    private var currentUpdated = ""
    private var isInEntry = false

    init(data: Data) {
        parser = XMLParser(data: data)
        super.init()
        parser.delegate = self
    }

    func parse() throws -> [ServiceIncident] {
        guard parser.parse() else {
            throw parser.parserError ?? OfficialStatusError.missingHTML
        }
        return incidents.sorted { $0.updatedAt > $1.updatedAt }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "entry" {
            isInEntry = true
            currentTitle = ""
            currentID = ""
            currentLink = ""
            currentSummary = ""
            currentUpdated = ""
        }
        if isInEntry, elementName == "link", let href = attributeDict["href"] {
            currentLink = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInEntry else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "id": currentID += string
        case "summary": currentSummary += string
        case "updated": currentUpdated += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "entry" {
            let summary = decodeEntities(currentSummary)
            let date = ISO8601DateFormatter().date(from: currentUpdated.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date.distantPast
            incidents.append(ServiceIncident(
                id: currentID.trimmingCharacters(in: .whitespacesAndNewlines),
                title: decodeEntities(currentTitle).trimmingCharacters(in: .whitespacesAndNewlines),
                link: URL(string: currentLink.trimmingCharacters(in: .whitespacesAndNewlines)),
                updatedAt: date,
                status: extractStatus(from: summary),
                affectedComponents: extractAffectedComponents(from: summary)
            ))
            isInEntry = false
        }
        currentElement = ""
    }

    private func extractStatus(from summary: String) -> String {
        let pattern = #"<strong>Status:</strong>\s*([^<]+)"#
        return firstMatch(in: summary, pattern: pattern)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func extractAffectedComponents(from summary: String) -> [String] {
        let pattern = #"<strong>Affected components:</strong>\s*([^<]+)"#
        guard let value = firstMatch(in: summary, pattern: pattern) else { return [] }
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#xA;", with: "\n")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}
