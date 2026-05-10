import Foundation

enum UsageParser {
    static let projectsURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")

    static func parseAll() async throws -> [String: [UsageEntry]] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: projectsURL.path) else { return [:] }

        let projectDirs = try fm.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }

        return try await withThrowingTaskGroup(of: (String, [UsageEntry]).self) { group in
            for projectDir in projectDirs {
                group.addTask {
                    let id = projectDir.lastPathComponent
                    let entries = await parseProject(at: projectDir)
                    return (id, entries)
                }
            }
            var result: [String: [UsageEntry]] = [:]
            for try await (id, entries) in group where !entries.isEmpty {
                result[id] = entries
            }
            return result
        }
    }

    private static func parseProject(at dir: URL) async -> [UsageEntry] {
        let fm = FileManager.default
        let jsonlFiles = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))
            .map { $0.filter { $0.pathExtension == "jsonl" } } ?? []

        var entries: [UsageEntry] = []
        for file in jsonlFiles {
            entries.append(contentsOf: parseJSONL(at: file))
        }
        return entries
    }

    static func parseJSONL(at url: URL) -> [UsageEntry] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateFormatterBasic = ISO8601DateFormatter()

        var entries: [UsageEntry] = []
        var seenIds = Set<String>()

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = String(line).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["type"] as? String == "assistant",
                  let message = json["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any]
            else { continue }

            let inputTokens = usage["input_tokens"] as? Int ?? 0
            let outputTokens = usage["output_tokens"] as? Int ?? 0
            let cacheCreate = usage["cache_creation_input_tokens"] as? Int ?? 0
            let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
            guard inputTokens + outputTokens + cacheCreate + cacheRead > 0 else { continue }

            let msgId = message["id"] as? String ?? ""
            let reqId = json["requestId"] as? String ?? ""
            let dedupKey = "\(msgId):\(reqId)"
            guard !dedupKey.isEmpty, !seenIds.contains(dedupKey) else { continue }
            seenIds.insert(dedupKey)

            let tsStr = json["timestamp"] as? String ?? ""
            let timestamp = dateFormatter.date(from: tsStr)
                ?? dateFormatterBasic.date(from: tsStr)
                ?? Date.distantPast

            entries.append(UsageEntry(
                timestamp: timestamp,
                model: message["model"] as? String ?? "unknown",
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: cacheCreate,
                cacheReadTokens: cacheRead,
                sessionId: json["sessionId"] as? String ?? "",
                isSidechain: json["isSidechain"] as? Bool ?? false,
                cwd: json["cwd"] as? String,
                gitBranch: json["gitBranch"] as? String
            ))
        }
        return entries
    }
}
