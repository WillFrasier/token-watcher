import Foundation

public enum UsageParser {
    public static let projectsURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")

    public static func parseAll() async throws -> [String: [UsageEntry]] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: projectsURL.path) else { return [:] }

        let projectDirs = try fm.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }

        let result = try await withThrowingTaskGroup(of: (String, [UsageEntry]).self) { group in
            for dir in projectDirs {
                group.addTask {
                    let id = dir.lastPathComponent
                    let entries = await parseProject(at: dir)
                    return (id, entries)
                }
            }
            var r: [String: [UsageEntry]] = [:]
            for try await (id, entries) in group where !entries.isEmpty {
                r[id] = entries
            }
            return r
        }

        await FileCache.shared.persist()
        return result
    }

    public static func parseProject(at dir: URL, cache: FileCache = FileCache.shared) async -> [UsageEntry] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]))?
            .filter { $0.pathExtension == "jsonl" } ?? []

        var allEntries: [UsageEntry] = []
        for file in files {
            allEntries.append(contentsOf: await loadFile(at: file, cache: cache))
        }
        return allEntries
    }

    // Cache-aware file loader. Returns cached entries for unchanged files,
    // reads only new bytes for appended files, full-parses new/replaced files.
    static func loadFile(at url: URL, cache: FileCache = FileCache.shared) async -> [UsageEntry] {
        // FileManager avoids the URL resource-value cache, which can return stale file sizes
        // within a single process lifetime after the file has been written to.
        let fileSize = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int) ?? 0
        let cached = await cache.entry(for: url)

        if let cached {
            if fileSize == cached.byteOffset {
                return cached.entries
            } else if fileSize > cached.byteOffset {
                if let chunk = readChunk(from: url, offset: cached.byteOffset) {
                    let newEntries = parseLines(chunk)
                    var entries = cached.entries
                    var dedup = cached.dedupIndex
                    merge(into: &entries, dedupIndex: &dedup, new: newEntries)
                    await cache.set(
                        FileCacheEntry(byteOffset: fileSize, entries: entries, dedupIndex: dedup),
                        for: url
                    )
                    return entries
                }
            }
            // fileSize < cached.byteOffset → file was replaced/truncated, fall through to full parse
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let (entries, dedup) = parseLinesDetailed(content)
        await cache.set(
            FileCacheEntry(byteOffset: fileSize, entries: entries, dedupIndex: dedup),
            for: url
        )
        return entries
    }

    private static func readChunk(from url: URL, offset: Int) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        try? handle.seek(toOffset: UInt64(offset))
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func merge(into entries: inout [UsageEntry], dedupIndex: inout [String: Int], new: [UsageEntry]) {
        for entry in new {
            if !entry.dedupKey.isEmpty, let idx = dedupIndex[entry.dedupKey] {
                entries[idx] = entry
            } else {
                if !entry.dedupKey.isEmpty { dedupIndex[entry.dedupKey] = entries.count }
                entries.append(entry)
            }
        }
    }

    public static func parseJSONL(at url: URL) -> [UsageEntry] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parseLines(content)
    }

    public static func parseLines(_ content: String) -> [UsageEntry] {
        parseLinesDetailed(content).0
    }

    private static func parseLinesDetailed(_ content: String) -> ([UsageEntry], [String: Int]) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateFormatterBasic = ISO8601DateFormatter()

        var dedupIndex: [String: Int] = [:]
        var entries: [UsageEntry] = []

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = String(line).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["type"] as? String == "assistant",
                  json["isApiErrorMessage"] as? Bool != true,
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

            let tsStr = json["timestamp"] as? String ?? ""
            let timestamp = dateFormatter.date(from: tsStr)
                ?? dateFormatterBasic.date(from: tsStr)
                ?? Date.distantPast

            let entry = UsageEntry(
                timestamp: timestamp,
                model: message["model"] as? String ?? "unknown",
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: cacheCreate,
                cacheReadTokens: cacheRead,
                sessionId: json["sessionId"] as? String ?? "",
                isSidechain: json["isSidechain"] as? Bool ?? false,
                cwd: json["cwd"] as? String,
                gitBranch: json["gitBranch"] as? String,
                speed: usage["speed"] as? String ?? "standard",
                dedupKey: dedupKey
            )

            if !dedupKey.isEmpty, let existing = dedupIndex[dedupKey] {
                entries[existing] = entry
            } else {
                if !dedupKey.isEmpty { dedupIndex[dedupKey] = entries.count }
                entries.append(entry)
            }
        }
        return (entries, dedupIndex)
    }
}
