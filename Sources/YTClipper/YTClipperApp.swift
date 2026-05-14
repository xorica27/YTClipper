import SwiftUI
import AppKit

@main
struct YTClipperApp: App {
    @AppStorage("prefersDarkMode") private var prefersDarkMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 820, minHeight: 680)
                .preferredColorScheme(prefersDarkMode ? .dark : .light)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .preferredColorScheme(prefersDarkMode ? .dark : .light)
        }
    }
}

struct ContentView: View {
    @StateObject private var model = DownloaderViewModel()

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    sourceSection

                    if !model.downloadFullVideo {
                        clipSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    destinationSection
                    actionSection
                    helperSection
                    logView
                }
                .padding(24)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: model.downloadFullVideo)
        .animation(.easeInOut(duration: 0.2), value: model.isRunning)
        .task {
            await model.refreshToolStatus()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.white.opacity(0.24))
                    )

                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("YTClipper")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("Download a full video or save a precise clip from your own YouTube uploads.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(model.status, systemImage: model.isRunning ? "bolt.circle.fill" : "checkmark.circle.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(model.isRunning ? .blue : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: Capsule())
        }
    }

    private var sourceSection: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Source", systemImage: "link")

                TextField("https://www.youtube.com/watch?v=...", text: $model.videoURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .rounded))

                HStack(spacing: 14) {
                    fieldGroup("Mode") {
                        Picker("Mode", selection: downloadModeBinding) {
                            ForEach(DownloadMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .disabled(model.isRunning)
                    }

                    fieldGroup("Resolution") {
                        Picker("Resolution", selection: $model.selectedResolution) {
                            ForEach(VideoResolution.allCases) { resolution in
                                Text(resolution.label).tag(resolution)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .disabled(model.isRunning)
                    }
                }
            }
        }
    }

    private var clipSection: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Clip Timing", systemImage: "timeline.selection")

                HStack(spacing: 14) {
                    fieldGroup("Start") {
                        TextField("00:00", text: $model.startTime)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
                            .disabled(model.isRunning)
                    }

                    fieldGroup("Range") {
                        Picker("Clip Range", selection: $model.clipRangeMode) {
                            ForEach(ClipRangeMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .disabled(model.isRunning)
                    }

                    fieldGroup(model.clipRangeMode.trailingFieldLabel) {
                        TextField(model.clipRangeMode.trailingFieldPlaceholder, text: $model.duration)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
                            .disabled(model.isRunning)
                    }
                }
            }
        }
    }

    private var destinationSection: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Destination", systemImage: "folder")

                HStack(spacing: 12) {
                    Text(model.outputDirectory.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        model.chooseOutputDirectory()
                    } label: {
                        Label("Choose", systemImage: "folder")
                    }
                    .disabled(model.isRunning)
                }
            }
        }
    }

    private var actionSection: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await model.download()
                        }
                    } label: {
                        Label(model.isRunning ? "Working..." : "Download", systemImage: "arrow.down.circle.fill")
                            .frame(minWidth: 132)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.isRunning)

                    Button(role: .destructive) {
                        model.stopDownload()
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                    .controlSize(.large)
                    .disabled(!model.isRunning)

                    Spacer()

                    if model.isRunning {
                        ProgressView()
                            .controlSize(.small)
                            .transition(.opacity)
                    }
                }

                downloadProgress
            }
        }
    }

    private var helperSection: some View {
        glassPanel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.hasMissingHelpers ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(model.hasMissingHelpers ? .orange : .green)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.hasMissingHelpers ? "Helpers need attention" : "Helpers ready")
                        .font(.headline)

                    Text(model.hasMissingHelpers ? "YTClipper needs yt-dlp and ffmpeg to download and process videos." : "yt-dlp and ffmpeg are available on this Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 3) {
                        Label(model.ytDlpStatus, systemImage: model.ytDlpPath == nil ? "xmark.circle" : "checkmark.circle")
                            .foregroundStyle(model.ytDlpPath == nil ? .red : .secondary)
                        Label(model.ffmpegStatus, systemImage: model.ffmpegPath == nil ? "xmark.circle" : "checkmark.circle")
                            .foregroundStyle(model.ffmpegPath == nil ? .red : .secondary)
                    }
                    .font(.caption)
                }

                Spacer()

                HStack(spacing: 8) {
                    recheckButton

                    if model.hasMissingHelpers {
                        Button {
                            model.installMissingHelpers()
                        } label: {
                            Label("Install", systemImage: "terminal")
                        }
                        .disabled(model.isRunning)
                    }
                }
            }
        }
    }

    private var recheckButton: some View {
        HStack {
            Button {
                Task {
                    await model.refreshToolStatus()
                }
            } label: {
                Label("Recheck Helpers", systemImage: "arrow.clockwise")
            }
            .disabled(model.isRunning)
        }
    }

    private var downloadProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progress")
                    .font(.callout.weight(.medium))
                Spacer()
                Text(model.progressLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            if let progressFraction = model.progressFraction {
                ProgressView(value: progressFraction, total: 1)
                    .progressViewStyle(.linear)
            } else {
                ProgressView(value: model.isRunning ? nil : 0, total: 1)
                    .progressViewStyle(.linear)
            }
        }
    }

    private var logView: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionHeader("Output Log", systemImage: "terminal")
                    Spacer()
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(model.log.isEmpty ? "No output yet." : model.log)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                            .id("log-bottom")
                    }
                    .frame(minHeight: 132, maxHeight: 200)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.6))
                    )
                    .onChange(of: model.log) { _ in
                        proxy.scrollTo("log-bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var downloadModeBinding: Binding<DownloadMode> {
        Binding(
            get: { model.downloadFullVideo ? .full : .clip },
            set: { model.downloadFullVideo = $0 == .full }
        )
    }

    private func glassPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55))
            )
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 8)
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func fieldGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum DownloadMode: String, CaseIterable, Identifiable {
    case full
    case clip

    var id: String { rawValue }

    var label: String {
        switch self {
        case .full: return "Full Video"
        case .clip: return "Clip"
        }
    }
}

struct SettingsView: View {
    @AppStorage("prefersDarkMode") private var prefersDarkMode = false

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Dark mode", isOn: $prefersDarkMode)
                    .toggleStyle(.switch)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}

@MainActor
final class DownloaderViewModel: ObservableObject {
    @Published var videoURL = ""
    @Published var downloadFullVideo = false
    @Published var startTime = "00:00"
    @Published var duration = "00:30"
    @Published var clipRangeMode: ClipRangeMode = .duration
    @Published var selectedResolution: VideoResolution = .best
    @Published var outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    @Published var log = ""
    @Published var status = "Ready"
    @Published var isRunning = false
    @Published var progressFraction: Double?
    @Published var progressLabel = "Idle"
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

    var hasMissingHelpers: Bool {
        !missingHelperPackages.isEmpty
    }

    private var missingHelperPackages: [String] {
        var packages: [String] = []
        if ytDlpPath == nil {
            packages.append("yt-dlp")
        }
        if ffmpegPath == nil {
            packages.append("ffmpeg")
        }
        return packages
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

    func installMissingHelpers() {
        let packages = missingHelperPackages
        guard !packages.isEmpty else {
            status = "Helpers ready"
            return
        }

        do {
            let scriptURL = try HelperInstallScriptWriter.write(packages: packages)
            NSWorkspace.shared.open(scriptURL)
            status = "Installing helpers"
            appendLog("Opened Terminal to install: \(packages.joined(separator: ", "))\n")
        } catch {
            status = "Install script failed"
            appendLog("Could not create helper install script: \(error.localizedDescription)\n")
        }
    }

    func download() async {
        await refreshToolStatus()
        log = ""
        status = "Validating"
        progressFraction = nil
        progressLabel = "Preparing"

        guard let ytDlpPath else {
            appendLog("Missing yt-dlp.\nInstall it with:\n  brew install yt-dlp")
            status = "Missing yt-dlp"
            progressLabel = "Missing yt-dlp"
            return
        }

        guard let ffmpegPath else {
            appendLog("Missing ffmpeg.\nInstall it with:\n  brew install ffmpeg")
            status = "Missing ffmpeg"
            progressLabel = "Missing ffmpeg"
            return
        }

        guard let url = URL(string: videoURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased(),
              host.contains("youtube.com") || host.contains("youtu.be") else {
            appendLog("Enter a valid YouTube URL.")
            status = "Invalid URL"
            progressLabel = "Invalid URL"
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
                  let endSeconds = clipRangeMode.endSeconds(startSeconds: startSeconds, trailingValue: duration),
                  endSeconds > startSeconds else {
                appendLog("Clip range must be valid. Use SS, MM:SS, or HH:MM:SS, and make sure the end is after the start.\n")
                status = "Invalid clip time"
                progressLabel = "Invalid clip time"
                return
            }

            let section = "*\(TimecodeParser.string(from: startSeconds))-\(TimecodeParser.string(from: endSeconds))"
            args += [
                "--download-sections", section,
                "--force-keyframes-at-cuts"
            ]
        }

        args.append(videoURL.trimmingCharacters(in: .whitespacesAndNewlines))

        isRunning = true
        status = downloadFullVideo ? "Downloading full video" : "Downloading clip"
        progressLabel = "Starting"
        appendLog("$ \(ytDlpPath) \(args.joined(separator: " "))\n")

        let processController = ProcessController()
        activeProcess = processController

        let result = await ProcessRunner.run(executable: ytDlpPath, arguments: args, controller: processController) { [weak self] chunk in
            Task { @MainActor in
                self?.handleProcessOutput(chunk)
            }
        }

        isRunning = false
        activeProcess = nil

        switch result {
        case .success:
            status = "Done"
            progressFraction = 1
            progressLabel = "100%"
            appendLog("\nDone. Saved to: \(outputDirectory.path)\n")
        case .cancelled:
            status = "Stopped"
            progressLabel = "Stopped"
            appendLog("\nStopped by user.\n")
        case .failure(let message):
            status = "Failed"
            progressLabel = "Failed"
            appendLog("\nFailed:\n\(message)\n")
        }
    }

    func stopDownload() {
        guard isRunning else { return }
        status = "Stopping"
        progressLabel = "Stopping"
        activeProcess?.cancel()
        appendLog("\nStopping download...\n")
    }

    private func handleProcessOutput(_ text: String) {
        appendLog(text)

        guard let progress = DownloadProgressParser.parse(text) else {
            if text.contains("[Merger]") || text.contains("Merging formats") {
                progressLabel = "Merging"
            } else if text.contains("[ExtractAudio]") || text.contains("[VideoRemuxer]") {
                progressLabel = "Processing"
            } else if text.contains("[info]") || text.contains("[youtube]") {
                progressLabel = "Preparing"
            }
            return
        }

        progressFraction = progress.fraction
        progressLabel = progress.label
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

enum HelperInstallScriptWriter {
    static func write(packages: [String]) throws -> URL {
        let safePackages = packages.filter { ["yt-dlp", "ffmpeg"].contains($0) }
        let installList = safePackages.joined(separator: " ")
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("YTClipper", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let scriptURL = tempDirectory.appendingPathComponent("install-missing-helpers.command")
        let script = """
        #!/bin/zsh
        set -e

        export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

        echo "YTClipper helper installer"
        echo "=========================="
        echo ""

        if ! command -v brew >/dev/null 2>&1; then
          echo "Homebrew is required before YTClipper can install helpers automatically."
          echo "Opening https://brew.sh now."
          open "https://brew.sh"
          echo ""
          read -k "?Press any key to close this window..."
          exit 1
        fi

        echo "Installing: \(installList)"
        echo ""
        brew install \(installList)
        echo ""
        echo "Done. Return to YTClipper and click Recheck."
        read -k "?Press any key to close this window..."
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        return scriptURL
    }
}

enum ClipRangeMode: String, CaseIterable, Identifiable {
    case duration
    case endTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .duration: return "Duration"
        case .endTime: return "End Time"
        }
    }

    var trailingFieldLabel: String {
        switch self {
        case .duration: return "Duration"
        case .endTime: return "End"
        }
    }

    var trailingFieldPlaceholder: String {
        switch self {
        case .duration: return "00:30"
        case .endTime: return "01:45"
        }
    }

    func endSeconds(startSeconds: Int, trailingValue: String) -> Int? {
        guard let value = TimecodeParser.seconds(from: trailingValue) else { return nil }

        switch self {
        case .duration:
            return startSeconds + value
        case .endTime:
            return value
        }
    }
}

struct DownloadProgress {
    let fraction: Double
    let label: String
}

enum DownloadProgressParser {
    static func parse(_ text: String) -> DownloadProgress? {
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
