import Foundation
import WebKit

/// Baut aus den Blocklisten eine WebKit-Regelliste (gleiche Technik wie Safari-Inhaltsblocker).
/// Quellen: eingebaute Liste (hosts.txt) + grosse StevenBlack-Liste, wöchentlich aktualisiert.
final class Blocker {
    static let shared = Blocker()

    private let listURL = URL(string: "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts")!

    // Diese Domains werden NIE blockiert, sonst laufen keine Videos mehr
    private let neverBlock = ["youtube.com", "youtu.be", "googlevideo.com", "ytimg.com",
                              "ggpht.com", "youtube-nocookie.com", "gstatic.com", "accounts.google.com"]

    // Pfad-Regeln: Werbung, die über "erlaubte" Domains kommt
    private let pathRules = ["/pagead/", "/pagead2.", "/api/stats/ads", "/ptracking",
                             "/get_midroll_", "/ad_break", "/adview", "/doubleclick/",
                             "/youtubei/v1/log_event", "&ad_type=", "?ad_type="]

    private(set) var ruleList: WKContentRuleList?
    private(set) var domainCount = 0

    private var supportDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private var cacheFile: URL { supportDir.appendingPathComponent("hosts_extra.txt") }

    // MARK: Listen lesen

    private func parse(_ text: String, into set: inout Set<String>) {
        for raw in text.split(whereSeparator: \.isNewline) {
            var line = Substring(raw)
            if let hash = line.firstIndex(of: "#") { line = line[..<hash] }
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            let host: Substring
            if parts.count >= 2, (parts[0] == "0.0.0.0" || parts[0] == "127.0.0.1") {
                host = parts[1]
            } else if parts.count == 1 {
                host = parts[0]
            } else {
                continue
            }
            let h = host.lowercased()
            if h == "localhost" || h == "0.0.0.0" || !h.contains(".") { continue }
            set.insert(h)
        }
    }

    private func loadDomains() -> Set<String> {
        var set = Set<String>()
        if let url = Bundle.main.url(forResource: "hosts", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            parse(text, into: &set)
        }
        if let text = try? String(contentsOf: cacheFile, encoding: .utf8) {
            parse(text, into: &set)
        }
        // geschützte Domains raus, und Unterdomains weglassen, wenn die Hauptdomain schon drin ist
        let neverBlock = self.neverBlock
        return set.filter { d in
            if neverBlock.contains(where: { d == $0 || d.hasSuffix("." + $0) }) { return false }
            var rest = Substring(d)
            while let dot = rest.firstIndex(of: ".") {
                rest = rest[rest.index(after: dot)...]
                if rest.contains("."), set.contains(String(rest)) { return false }
            }
            return true
        }
    }

    // MARK: Regeln bauen

    private func escape(_ s: String) -> String {
        var out = ""
        for ch in s {
            if ".?*+^$[]()\\".contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out
    }

    private func rulesJSON(for domains: Set<String>) -> String {
        var rules: [[String: Any]] = []
        rules.reserveCapacity(domains.count + pathRules.count)
        for d in domains {
            rules.append([
                "trigger": ["url-filter": "^[^:]+://+([^:/]+\\.)?" + escape(d) + "[:/]"],
                "action": ["type": "block"]
            ])
        }
        for p in pathRules {
            rules.append([
                "trigger": ["url-filter": escape(p)],
                "action": ["type": "block"]
            ])
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rules),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    private func listStamp() -> Int {
        let attrs = try? FileManager.default.attributesOfItem(atPath: cacheFile.path)
        let date = attrs?[.modificationDate] as? Date
        return Int(date?.timeIntervalSince1970 ?? 0)
    }

    /// Lädt (oder kompiliert beim ersten Mal) die Regelliste.
    func prepare(completion: @escaping (WKContentRuleList?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let domains = self.loadDomains()
            let id = "schildwall-\(domains.count)-\(self.listStamp())"
            DispatchQueue.main.async {
                let store: WKContentRuleListStore = WKContentRuleListStore.default()
                store.lookUpContentRuleList(forIdentifier: id) { existing, _ in
                    if let existing = existing {
                        self.finish(existing, count: domains.count, id: id, completion: completion)
                        return
                    }
                    DispatchQueue.global(qos: .userInitiated).async {
                        let json = self.rulesJSON(for: domains)
                        DispatchQueue.main.async {
                            store.compileContentRuleList(forIdentifier: id, encodedContentRuleList: json) { list, error in
                                if let list = list {
                                    self.finish(list, count: domains.count, id: id, completion: completion)
                                } else {
                                    NSLog("Schildwall: Regeln konnten nicht kompiliert werden: \(String(describing: error))")
                                    completion(self.ruleList)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func finish(_ list: WKContentRuleList, count: Int, id: String,
                        completion: @escaping (WKContentRuleList?) -> Void) {
        ruleList = list
        domainCount = count
        // alte Regel-Versionen aufräumen
        let store: WKContentRuleListStore = WKContentRuleListStore.default()
        store.getAvailableContentRuleListIdentifiers { ids in
            for old in ids ?? [] where old != id {
                store.removeContentRuleList(forIdentifier: old) { _ in }
            }
        }
        completion(list)
    }

    // MARK: Update der grossen Liste

    var needsUpdate: Bool {
        let stamp = listStamp()
        if stamp == 0 { return true }
        return Date().timeIntervalSince1970 - Double(stamp) > 7 * 24 * 3600
    }

    func downloadList(completion: @escaping (Bool) -> Void) {
        var req = URLRequest(url: listURL)
        req.timeoutInterval = 30
        URLSession.shared.dataTask(with: req) { data, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            if ok, let data = data, data.count > 10_000 {
                do {
                    try data.write(to: self.cacheFile, options: .atomic)
                    DispatchQueue.main.async { completion(true) }
                    return
                } catch {}
            }
            DispatchQueue.main.async { completion(false) }
        }.resume()
    }
}
