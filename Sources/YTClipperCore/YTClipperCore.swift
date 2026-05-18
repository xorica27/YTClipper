import Foundation

public enum DownloadMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case full
    case clip

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .full: return "Full Video"
        case .clip: return "Clip"
        }
    }
}

public enum ClipRangeMode: String, CaseIterable, Identifiable, Sendable {
    case duration
    case endTime

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .duration: return "Duration"
        case .endTime: return "End Time"
        }
    }

    public var trailingFieldLabel: String {
        switch self {
        case .duration: return "Clip Duration"
        case .endTime: return "Clip Timestamp"
        }
    }

    public var trailingFieldPlaceholder: String {
        switch self {
        case .duration: return "00:30"
        case .endTime: return "01:45"
        }
    }

    public func endSeconds(startSeconds: Int, trailingValue: String) -> Int? {
        guard let value = TimecodeParser.seconds(from: trailingValue) else { return nil }

        switch self {
        case .duration:
            return startSeconds + value
        case .endTime:
            return value
        }
    }
}

public enum VideoResolution: String, CaseIterable, Codable, Identifiable, Sendable {
    case best
    case p2160
    case p1440
    case p1080
    case p720
    case p480
    case p360

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .best: return "Best available"
        case .p2160: return "Up to 2160p / 4K"
        case .p1440: return "Up to 1440p / 2K"
        case .p1080: return "Up to 1080p"
        case .p720: return "Up to 720p"
        case .p480: return "Up to 480p"
        case .p360: return "Up to 360p"
        }
    }

    public var formatSelector: String {
        switch self {
        case .best:
            return "bv*+ba/best"
        case .p2160:
            return "bv*[height<=2160]+ba/b[height<=2160]/best[height<=2160]"
        case .p1440:
            return "bv*[height<=1440]+ba/b[height<=1440]/best[height<=1440]"
        case .p1080:
            return "bv*[height<=1080]+ba/b[height<=1080]/best[height<=1080]"
        case .p720:
            return "bv*[height<=720]+ba/b[height<=720]/best[height<=720]"
        case .p480:
            return "bv*[height<=480]+ba/b[height<=480]/best[height<=480]"
        case .p360:
            return "bv*[height<=360]+ba/b[height<=360]/best[height<=360]"
        }
    }
}

public enum TimecodeParser {
    public static func seconds(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directSeconds = Int(trimmed), directSeconds >= 0 {
            return directSeconds
        }

        let parts = trimmed.split(separator: ":").map(String.init)
        guard (2...3).contains(parts.count),
              parts.allSatisfy({ Int($0) != nil }) else {
            return nil
        }

        let values = parts.compactMap(Int.init)
        guard values.count == parts.count, values.allSatisfy({ $0 >= 0 }) else {
            return nil
        }

        if values.count == 2 {
            let minutes = values[0]
            let seconds = values[1]
            guard seconds < 60 else { return nil }
            return minutes * 60 + seconds
        }

        let hours = values[0]
        let minutes = values[1]
        let seconds = values[2]
        guard minutes < 60, seconds < 60 else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }

    public static func string(from seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }
}

public struct URLListParseResult: Equatable, Sendable {
    public let urls: [String]
    public let invalidEntries: [String]
}

public enum URLListParser {
    public static func parse(_ text: String) -> URLListParseResult {
        var urls: [String] = []
        var invalidEntries: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if DownloadRequest.isValidYouTubeURL(line) {
                urls.append(line)
            } else {
                invalidEntries.append(line)
            }
        }

        return URLListParseResult(urls: urls, invalidEntries: invalidEntries)
    }
}

public enum DownloadValidationError: LocalizedError, Equatable {
    case invalidURL(String)
    case invalidClipRange
    case missingClipRange
    case emptyBatch
    case unsupportedManifestVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid YouTube URL: \(url)"
        case .invalidClipRange:
            return "Clip range must be valid and end after the start."
        case .missingClipRange:
            return "Clip mode requires a clip range."
        case .emptyBatch:
            return "Manifest must include at least one job."
        case .unsupportedManifestVersion(let version):
            return "Unsupported manifest version: \(version)"
        }
    }
}

public struct ClipRange: Equatable, Sendable {
    public let startSeconds: Int
    public let endSeconds: Int

    public init(start: String, duration: String) throws {
        guard let startSeconds = TimecodeParser.seconds(from: start),
              let durationSeconds = TimecodeParser.seconds(from: duration),
              durationSeconds > 0 else {
            throw DownloadValidationError.invalidClipRange
        }

        self.startSeconds = startSeconds
        self.endSeconds = startSeconds + durationSeconds
    }

    public init(start: String, endTime: String) throws {
        guard let startSeconds = TimecodeParser.seconds(from: start),
              let endSeconds = TimecodeParser.seconds(from: endTime),
              endSeconds > startSeconds else {
            throw DownloadValidationError.invalidClipRange
        }

        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }

    public var downloadSection: String {
        "*\(TimecodeParser.string(from: startSeconds))-\(TimecodeParser.string(from: endSeconds))"
    }
}

public struct DownloadRequest: Equatable, Sendable {
    public let url: String
    public let mode: DownloadMode
    public let resolution: VideoResolution
    public let outputDirectory: URL
    public let clipRange: ClipRange?

    public init(
        url: String,
        mode: DownloadMode,
        resolution: VideoResolution,
        outputDirectory: URL,
        clipRange: ClipRange?
    ) throws {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidYouTubeURL(trimmedURL) else {
            throw DownloadValidationError.invalidURL(url)
        }
        if mode == .clip, clipRange == nil {
            throw DownloadValidationError.missingClipRange
        }

        self.url = trimmedURL
        self.mode = mode
        self.resolution = resolution
        self.outputDirectory = outputDirectory
        self.clipRange = clipRange
    }

    public static func isValidYouTubeURL(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased(),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return false
        }
        return host.contains("youtube.com") || host.contains("youtu.be")
    }

    public func ytDlpArguments(ffmpegPath: String) -> [String] {
        var args = [
            "--newline",
            "--no-playlist",
            "--ffmpeg-location", ffmpegPath,
            "-f", resolution.formatSelector,
            "--merge-output-format", "mp4",
            "-P", outputDirectory.path,
            "-o", "%(title).80s-%(id)s.%(ext)s"
        ]

        if mode == .clip, let clipRange {
            args += [
                "--download-sections", clipRange.downloadSection,
                "--force-keyframes-at-cuts"
            ]
        }

        args.append(url)
        return args
    }
}

public struct DownloadBatch: Sendable {
    public let requests: [DownloadRequest]
    public let continueOnFailure: Bool

    public init(requests: [DownloadRequest], continueOnFailure: Bool = true) {
        self.requests = requests
        self.continueOnFailure = continueOnFailure
    }
}

public struct DownloadItemResult: Equatable, Sendable {
    public let index: Int
    public let url: String
    public let status: String
    public let message: String?
}

public struct DownloadSummary: Equatable, Sendable {
    public let succeeded: Int
    public let failed: Int
    public let cancelled: Int
    public let results: [DownloadItemResult]

    public var hasFailures: Bool {
        failed > 0 || cancelled > 0
    }
}

public struct DownloadProgress: Equatable, Sendable {
    public let fraction: Double
    public let label: String
}

public enum DownloadProgressParser {
    public static func parse(_ text: String) -> DownloadProgress? {
        let pattern = #"\[download\]\s+([0-9]+(?:\.[0-9]+)?)%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.matches(in: text, range: range).last,
              let percentRange = Range(match.range(at: 1), in: text),
              let percent = Double(text[percentRange]) else {
            return nil
        }

        let clampedPercent = min(max(percent, 0), 100)
        return DownloadProgress(
            fraction: clampedPercent / 100,
            label: String(format: "%.1f%%", clampedPercent)
        )
    }
}

public enum ProcessRunResult: Equatable, Sendable {
    case success
    case cancelled
    case failure(String)
}

public final class ProcessController: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    public init() {}

    public func attach(_ process: Process) {
        lock.withLock {
            self.process = process
            if cancelled {
                process.terminate()
            }
        }
    }

    public func cancel() {
        lock.withLock {
            cancelled = true
            process?.terminate()
        }
    }

    public var isCancelled: Bool {
        lock.withLock { cancelled }
    }
}

public protocol CommandRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        controller: ProcessController,
        onOutput: @escaping @Sendable (String) -> Void
    ) async -> ProcessRunResult
}

public final class SystemCommandRunner: CommandRunning {
    public init() {}

    public func run(
        executable: String,
        arguments: [String],
        controller: ProcessController,
        onOutput: @escaping @Sendable (String) -> Void
    ) async -> ProcessRunResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            controller.attach(process)

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let errorOutput = LockedTextBuffer()

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                onOutput(text)
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                errorOutput.append(text)
                onOutput(text)
            }

            process.terminationHandler = { finishedProcess in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                if controller.isCancelled {
                    continuation.resume(returning: .cancelled)
                } else if finishedProcess.terminationStatus == 0 {
                    continuation.resume(returning: .success)
                } else {
                    let message = errorOutput.text
                    continuation.resume(returning: .failure(message.isEmpty ? "yt-dlp exited with status \(finishedProcess.terminationStatus)." : message))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: .failure(error.localizedDescription))
            }
        }
    }
}

public final class BatchDownloader: @unchecked Sendable {
    private let ytDlpPath: String
    private let ffmpegPath: String
    private let commandRunner: CommandRunning
    private let lock = NSLock()
    private var activeController: ProcessController?
    private var cancelled = false

    public init(
        ytDlpPath: String,
        ffmpegPath: String,
        commandRunner: CommandRunning = SystemCommandRunner()
    ) {
        self.ytDlpPath = ytDlpPath
        self.ffmpegPath = ffmpegPath
        self.commandRunner = commandRunner
    }

    public func cancel() {
        lock.withLock {
            cancelled = true
            activeController?.cancel()
        }
    }

    public func run(
        batch: DownloadBatch,
        onEvent: @escaping @Sendable (DownloadEvent) -> Void
    ) async -> DownloadSummary {
        onEvent(.batchStarted(total: batch.requests.count))

        var results: [DownloadItemResult] = []
        var succeeded = 0
        var failed = 0
        var cancelledCount = 0

        for (index, request) in batch.requests.enumerated() {
            if isCancelled {
                cancelledCount += 1
                let result = DownloadItemResult(index: index, url: request.url, status: "cancelled", message: "Cancelled before starting.")
                results.append(result)
                onEvent(.itemCancelled(index: index, url: request.url, message: result.message))
                continue
            }

            onEvent(.itemStarted(index: index, url: request.url))

            let controller = ProcessController()
            lock.withLock {
                activeController = controller
            }

            let result = await commandRunner.run(
                executable: ytDlpPath,
                arguments: request.ytDlpArguments(ffmpegPath: ffmpegPath),
                controller: controller
            ) { output in
                onEvent(.log(index: index, message: output))
                if let progress = DownloadProgressParser.parse(output) {
                    onEvent(.progress(index: index, fraction: progress.fraction, label: progress.label))
                }
            }

            lock.withLock {
                if activeController === controller {
                    activeController = nil
                }
            }

            switch result {
            case .success:
                succeeded += 1
                results.append(DownloadItemResult(index: index, url: request.url, status: "succeeded", message: nil))
                onEvent(.itemCompleted(index: index, url: request.url))
            case .cancelled:
                cancelledCount += 1
                results.append(DownloadItemResult(index: index, url: request.url, status: "cancelled", message: "Cancelled."))
                onEvent(.itemCancelled(index: index, url: request.url, message: "Cancelled."))
            case .failure(let message):
                failed += 1
                results.append(DownloadItemResult(index: index, url: request.url, status: "failed", message: message))
                onEvent(.itemFailed(index: index, url: request.url, message: message))
                if !batch.continueOnFailure {
                    cancel()
                }
            }
        }

        let summary = DownloadSummary(
            succeeded: succeeded,
            failed: failed,
            cancelled: cancelledCount,
            results: results
        )
        onEvent(.batchCompleted(summary: summary))
        return summary
    }

    private var isCancelled: Bool {
        lock.withLock { cancelled }
    }
}

public struct DownloadEvent: Codable, Equatable, Sendable {
    public let type: String
    public let total: Int?
    public let index: Int?
    public let url: String?
    public let fraction: Double?
    public let label: String?
    public let status: String?
    public let message: String?
    public let succeeded: Int?
    public let failed: Int?
    public let cancelled: Int?

    private init(
        type: String,
        total: Int? = nil,
        index: Int? = nil,
        url: String? = nil,
        fraction: Double? = nil,
        label: String? = nil,
        status: String? = nil,
        message: String? = nil,
        succeeded: Int? = nil,
        failed: Int? = nil,
        cancelled: Int? = nil
    ) {
        self.type = type
        self.total = total
        self.index = index
        self.url = url
        self.fraction = fraction
        self.label = label
        self.status = status
        self.message = message
        self.succeeded = succeeded
        self.failed = failed
        self.cancelled = cancelled
    }

    public static func batchStarted(total: Int) -> DownloadEvent {
        DownloadEvent(type: "batch_started", total: total)
    }

    public static func itemStarted(index: Int, url: String) -> DownloadEvent {
        DownloadEvent(type: "item_started", index: index, url: url)
    }

    public static func progress(index: Int, fraction: Double, label: String) -> DownloadEvent {
        DownloadEvent(type: "progress", index: index, fraction: fraction, label: label)
    }

    public static func log(index: Int, message: String) -> DownloadEvent {
        DownloadEvent(type: "log", index: index, message: message)
    }

    public static func itemCompleted(index: Int, url: String) -> DownloadEvent {
        DownloadEvent(type: "item_completed", index: index, url: url, status: "succeeded")
    }

    public static func itemFailed(index: Int, url: String, message: String) -> DownloadEvent {
        DownloadEvent(type: "item_failed", index: index, url: url, status: "failed", message: message)
    }

    public static func itemCancelled(index: Int, url: String, message: String?) -> DownloadEvent {
        DownloadEvent(type: "item_cancelled", index: index, url: url, status: "cancelled", message: message)
    }

    public static func batchCompleted(summary: DownloadSummary) -> DownloadEvent {
        DownloadEvent(
            type: "batch_completed",
            succeeded: summary.succeeded,
            failed: summary.failed,
            cancelled: summary.cancelled
        )
    }
}

public enum AgentManifestDecoder {
    public static func decode(_ data: Data) throws -> DownloadBatch {
        let manifest = try JSONDecoder().decode(AgentManifest.self, from: data)
        guard manifest.version == 1 else {
            throw DownloadValidationError.unsupportedManifestVersion(manifest.version)
        }
        guard !manifest.jobs.isEmpty else {
            throw DownloadValidationError.emptyBatch
        }

        let mode = manifest.mode ?? .full
        let resolution = manifest.resolution ?? .best
        let outputDirectory = URL(fileURLWithPath: manifest.outputDirectory)
        let clipRange = try manifest.clip?.toClipRange()
        if mode == .clip, clipRange == nil {
            throw DownloadValidationError.missingClipRange
        }

        let requests = try manifest.jobs.map { job in
            try DownloadRequest(
                url: job.url,
                mode: mode,
                resolution: resolution,
                outputDirectory: outputDirectory,
                clipRange: clipRange
            )
        }

        return DownloadBatch(requests: requests, continueOnFailure: manifest.continueOnFailure ?? true)
    }
}

private struct AgentManifest: Decodable {
    let version: Int
    let outputDirectory: String
    let mode: DownloadMode?
    let resolution: VideoResolution?
    let clip: AgentManifestClip?
    let continueOnFailure: Bool?
    let jobs: [AgentManifestJob]
}

private struct AgentManifestClip: Decodable {
    let start: String
    let duration: String?
    let endTime: String?

    func toClipRange() throws -> ClipRange {
        if let duration {
            return try ClipRange(start: start, duration: duration)
        }
        if let endTime {
            return try ClipRange(start: start, endTime: endTime)
        }
        throw DownloadValidationError.invalidClipRange
    }
}

private struct AgentManifestJob: Decodable {
    let url: String
}

public enum HelperLocator {
    public static func findExecutable(named name: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]

        if let match = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return match
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", name]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }

            let data = output.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return path?.isEmpty == false ? path : nil
        } catch {
            return nil
        }
    }
}

private final class LockedTextBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""

    func append(_ text: String) {
        lock.withLock {
            storage += text
        }
    }

    var text: String {
        lock.withLock { storage }
    }
}

extension NSLock {
    func withLock<T>(_ work: () -> T) -> T {
        lock()
        defer { unlock() }
        return work()
    }
}
