import SwiftUI
import AppKit

@main
struct YTClipperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 760, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    @StateObject private var model = DownloaderViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            form
            controls
            logView
        }
        .padding(24)
        .task {
            await model.refreshToolStatus()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YTClipper")
                .font(.system(size: 30, weight: .semibold))
            Text("Download your own public YouTube video, or save a precise clip range for reuse.")
                .foregroundStyle(.secondary)
            Text("Use only with videos you own or have permission to archive. This app does not bypass DRM, paywalls, or private access controls.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Text("YouTube URL")
                    .frame(width: 110, alignment: .trailing)
                TextField("https://www.youtube.com/watch?v=...", text: $model.videoURL)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text("Mode")
                    .frame(width: 110, alignment: .trailing)
                Toggle("Download full video", isOn: $model.downloadFullVideo)
                    .toggleStyle(.switch)
                    .disabled(model.isRunning)
            }

            GridRow {
                Text("Resolution")
                    .frame(width: 110, alignment: .trailing)
                Picker("Resolution", selection: $model.selectedResolution) {
                    ForEach(VideoResolution.allCases) { resolution in
                        Text(resolution.label).tag(resolution)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 240, alignment: .leading)
                .disabled(model.isRunning)
            }

            GridRow {
                Text("Start")
                    .frame(width: 110, alignment: .trailing)
                TextField("00:00", text: $model.startTime)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.downloadFullVideo || model.isRunning)
            }

            GridRow {
                Text("Duration")
                    .frame(width: 110, alignment: .trailing)
                TextField("00:30", text: $model.duration)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.downloadFullVideo || model.isRunning)
            }

            GridRow {
                Text("Save To")
                    .frame(width: 110, alignment: .trailing)
                HStack(spacing: 10) {
                    Text(model.outputDirectory.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Button {
                        model.chooseOutputDirectory()
                    } label: {
                        Label("Choose", systemImage: "folder")
                    }
                    .disabled(model.isRunning)
                }
            }

            GridRow {
                Text("Helpers")
                    .frame(width: 110, alignment: .trailing)
                VStack(alignment: .leading, spacing: 4) {
                    Label(model.ytDlpStatus, systemImage: model.ytDlpPath == nil ? "xmark.circle" : "checkmark.circle")
                        .foregroundStyle(model.ytDlpPath == nil ? .red : .green)
                    Label(model.ffmpegStatus, systemImage: model.ffmpegPath == nil ? "xmark.circle" : "checkmark.circle")
                        .foregroundStyle(model.ffmpegPath == nil ? .red : .green)
                }
                .font(.callout)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await model.download()
                }
            } label: {
                Label(model.isRunning ? "Working..." : "Download", systemImage: "arrow.down.circle.fill")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isRunning)

            Button(role: .destructive) {
                model.stopDownload()
            } label: {
                Label("Stop", systemImage: "stop.circle")
            }
            .disabled(!model.isRunning)

            Button {
                Task {
                    await model.refreshToolStatus()
                }
            } label: {
                Label("Recheck", systemImage: "arrow.clockwise")
            }
            .disabled(model.isRunning)

            if model.isRunning {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Text(model.status)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output")
                .font(.headline)
            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.log.isEmpty ? "No output yet." : model.log)
                        .font(.system(.callout, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                        .id("log-bottom")
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                )
                .onChange(of: model.log) { _ in
                    proxy.scrollTo("log-bottom", anchor: .bottom)
                }
            }
        }
    }
}

@MainActor
final class DownloaderViewModel: ObservableObject {
    @Published var videoURL = ""
    @Published var downloadFullVideo = false
    @Published var startTime = "00:00"
    @Published var duration = "00:30"
    @Published var selectedResolution: VideoResolution = .best
    @Published var outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    @Published var log = ""
    @Published var status = "Ready"
    @Published var isRunning = false
    @Published var ytDlpPath: String?
    @Published var ffmpegPath: String?
    private var activeProcess: ProcessController?

    var ytDlpStatus: String {
        guard let ytDlpPath else {
            return "yt-dlp missing. Install with: brew install yt-dlp"
        }
        return "yt-dlp: \(ytDlpPath)"
    }

    var ffmpegStatus: String {
        guard let ffmpegPath else {
            return "ffmpeg missing. Install with: brew install ffmpeg"
        }
        return "ffmpeg: \(ffmpegPath)"
    }

    func refreshToolStatus() async {
        ytDlpPath = findExecutable(named: "yt-dlp")
        ffmpegPath = findExecutable(named: "ffmpeg")
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputDirectory

        if panel.runModal() == .OK, let selectedURL = panel.url {
            outputDirectory = selectedURL
        }
    }

    func download() async {
        await refreshToolStatus()
        log = ""
        status = "Validating"

        guard let ytDlpPath else {
            appendLog("Missing yt-dlp.\nInstall it with:\n  brew install yt-dlp")
            status = "Missing yt-dlp"
            return
        }

        guard let ffmpegPath else {
            appendLog("Missing ffmpeg.\nInstall it with:\n  brew install ffmpeg")
            status = "Missing ffmpeg"
            return
        }

        guard let url = URL(string: videoURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased(),
              host.contains("youtube.com") || host.contains("youtu.be") else {
            appendLog("Enter a valid YouTube URL.")
            status = "Invalid URL"
            return
        }

        var args = [
            "--newline",
            "--no-playlist",
            "--ffmpeg-location", ffmpegPath,
            "-f", selectedResolution.formatSelector,
            "--merge-output-format", "mp4",
            "-P", outputDirectory.path,
            "-o", "%(title).80s-%(id)s.%(ext)s"
        ]

        if !downloadFullVideo {
            guard let startSeconds = TimecodeParser.seconds(from: startTime),
                  let durationSeconds = TimecodeParser.seconds(from: duration),
                  durationSeconds > 0 else {
                appendLog("Clip start and duration must be valid. Use SS, MM:SS, or HH:MM:SS.")
                status = "Invalid clip time"
                return
            }

            let endSeconds = startSeconds + durationSeconds
            let section = "*\(TimecodeParser.string(from: startSeconds))-\(TimecodeParser.string(from: endSeconds))"
            args += [
                "--download-sections", section,
                "--force-keyframes-at-cuts"
            ]
        }

        args.append(videoURL.trimmingCharacters(in: .whitespacesAndNewlines))

        isRunning = true
        status = downloadFullVideo ? "Downloading full video" : "Downloading clip"
        appendLog("$ \(ytDlpPath) \(args.joined(separator: " "))\n")

        let processController = ProcessController()
        activeProcess = processController

        let result = await ProcessRunner.run(executable: ytDlpPath, arguments: args, controller: processController) { [weak self] chunk in
            Task { @MainActor in
                self?.appendLog(chunk)
            }
        }

        isRunning = false
        activeProcess = nil

        switch result {
        case .success:
            status = "Done"
            appendLog("\nDone. Saved to: \(outputDirectory.path)\n")
        case .cancelled:
            status = "Stopped"
            appendLog("\nStopped by user.\n")
        case .failure(let message):
            status = "Failed"
            appendLog("\nFailed:\n\(message)\n")
        }
    }

    func stopDownload() {
        guard isRunning else { return }
        status = "Stopping"
        activeProcess?.cancel()
        appendLog("\nStopping download...\n")
    }

    private func appendLog(_ text: String) {
        log += text
    }

    private func findExecutable(named name: String) -> String? {
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

enum VideoResolution: String, CaseIterable, Identifiable {
    case best
    case p2160
    case p1440
    case p1080
    case p720
    case p480
    case p360

    var id: String { rawValue }

    var label: String {
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

    var formatSelector: String {
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

enum TimecodeParser {
    static func seconds(from text: String) -> Int? {
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

    static func string(from seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }
}

enum ProcessRunResult {
    case success
    case cancelled
    case failure(String)
}

final class ProcessController: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    func attach(_ process: Process) {
        lock.withLock {
            self.process = process
            if cancelled {
                process.terminate()
            }
        }
    }

    func cancel() {
        lock.withLock {
            cancelled = true
            process?.terminate()
        }
    }

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }
}

final class LockedTextBuffer: @unchecked Sendable {
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

enum ProcessRunner {
    static func run(
        executable: String,
        arguments: [String],
        controller: ProcessController,
        onOutput: @escaping (String) -> Void
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
