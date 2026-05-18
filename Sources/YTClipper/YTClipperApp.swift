import SwiftUI
import AppKit
import UniformTypeIdentifiers
import YTClipperCore

@main
struct YTClipperApp: App {
    @AppStorage("prefersDarkMode") private var prefersDarkMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 820, minHeight: 760)
                .preferredColorScheme(prefersDarkMode ? .dark : .light)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About YTClipper") {
                    AboutPanelPresenter.show()
                }
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(prefersDarkMode ? .dark : .light)
        }
    }
}

struct ContentView: View {
    @StateObject private var model = DownloaderViewModel()
    private let logViewportHeight: CGFloat = 180

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
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            AppIconMark(size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("YTClipper")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("Download a full video or save a precise clip from your own YT uploads.")
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

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $model.urlListText)
                        .font(.system(.body, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .disabled(model.isRunning)

                    if model.urlListText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Paste one YT video URL per line")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 92)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.6))
                )

                HStack(spacing: 10) {
                    Label(model.urlCountLabel, systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let invalidURLLabel = model.invalidURLLabel {
                        Label(invalidURLLabel, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    Button {
                        model.importURLListFromTextFile()
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .disabled(model.isRunning)
                }

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

                    fieldGroup("Clip Timestamp") {
                        TextField("00:00", text: $model.startTime)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
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
                    GeometryReader { geometry in
                        ScrollView(.vertical) {
                            Text(model.log.isEmpty ? "No output yet." : model.log)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: max(0, geometry.size.width - 24), alignment: .leading)
                                .textSelection(.enabled)
                                .padding(12)
                                .id("log-bottom")
                        }
                    }
                    .frame(height: logViewportHeight)
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

struct AppIconMark: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let image = AppIconLoader.image() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: size * 0.46, weight: .semibold))
                            .foregroundStyle(.blue)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

enum AppIconLoader {
    static func image() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "YTClipperIcon", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 22) {
            AppIconMark(size: 88)
                .padding(.top, 6)

            VStack(spacing: 6) {
                Text("YTClipper")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))

                Text("Version 0.2.0")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Save full videos or precise clips from YT content you own or have permission to archive.")
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 340)

            Divider()
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 12) {
                AboutInfoRow(
                    systemImage: "lock.shield",
                    title: "Private by default",
                    message: "Downloads stay on your Mac and run through local helper tools."
                )

                AboutInfoRow(
                    systemImage: "checkmark.seal",
                    title: "Use responsibly",
                    message: "Designed for YT content you own or have permission to save."
                )
            }
            .frame(maxWidth: 360)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .frame(width: 460, height: 430)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct AboutInfoRow: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor
enum AboutPanelPresenter {
    private static var panel: NSPanel?

    static func show() {
        if let panel {
            position(panel)
            panel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        panel.title = "About YTClipper"
        panel.contentViewController = NSHostingController(rootView: AboutView())
        panel.isReleasedWhenClosed = false
        position(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        Self.panel = panel
    }

    private static func position(_ panel: NSPanel) {
        let appWindow = NSApplication.shared.windows.first { window in
            window !== panel && window.isVisible && !window.isMiniaturized
        }

        let targetFrame = appWindow?.frame ?? screenUnderPointer()?.visibleFrame ?? NSScreen.main?.visibleFrame
        guard let targetFrame else {
            panel.center()
            return
        }

        var origin = NSPoint(
            x: targetFrame.midX - panel.frame.width / 2,
            y: targetFrame.midY - panel.frame.height / 2
        )

        if let visibleFrame = appWindow?.screen?.visibleFrame ?? screenUnderPointer()?.visibleFrame ?? NSScreen.main?.visibleFrame {
            origin.x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - panel.frame.width)
            origin.y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - panel.frame.height)
        }

        panel.setFrameOrigin(origin)
    }

    private static func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(pointer)
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
    @Published var urlListText = ""
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
    @Published var invalidURLs: [String] = []
    @Published var totalItems = 0
    @Published var activeItemIndex: Int?
    private var activeDownloader: BatchDownloader?

    var urlCountLabel: String {
        let parsed = URLListParser.parse(urlListText)
        let count = parsed.urls.count

        switch count {
        case 0: return "No URLs"
        case 1: return "1 URL"
        default: return "\(count) URLs"
        }
    }

    var invalidURLLabel: String? {
        let count = URLListParser.parse(urlListText).invalidEntries.count
        guard count > 0 else { return nil }
        return count == 1 ? "1 invalid URL" : "\(count) invalid URLs"
    }

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
        ytDlpPath = HelperLocator.findExecutable(named: "yt-dlp")
        ffmpegPath = HelperLocator.findExecutable(named: "ffmpeg")
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

    func importURLListFromTextFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, .text]

        if panel.runModal() == .OK, let selectedURL = panel.url {
            do {
                urlListText = try String(contentsOf: selectedURL, encoding: .utf8)
                let parsed = URLListParser.parse(urlListText)
                invalidURLs = parsed.invalidEntries
                status = "Imported \(parsed.urls.count) URL\(parsed.urls.count == 1 ? "" : "s")"
            } catch {
                status = "Import failed"
                appendLog("Could not read URL list: \(error.localizedDescription)\n")
            }
        }
    }

    func download() async {
        await refreshToolStatus()
        log = ""
        status = "Validating"
        progressFraction = nil
        progressLabel = "Preparing"
        invalidURLs = []
        totalItems = 0
        activeItemIndex = nil

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

        let parsedURLs = URLListParser.parse(urlListText)
        invalidURLs = parsedURLs.invalidEntries

        guard !parsedURLs.urls.isEmpty else {
            appendLog("Enter at least one valid YT URL.\n")
            status = "No URLs"
            progressLabel = "No URLs"
            return
        }

        guard parsedURLs.invalidEntries.isEmpty else {
            appendLog("Fix invalid URL entries before downloading:\n")
            parsedURLs.invalidEntries.forEach { appendLog("  \($0)\n") }
            status = "Invalid URLs"
            progressLabel = "Invalid URLs"
            return
        }

        let mode: DownloadMode = downloadFullVideo ? .full : .clip
        let clipRange: ClipRange?

        if !downloadFullVideo {
            do {
                switch clipRangeMode {
                case .duration:
                    clipRange = try ClipRange(start: startTime, duration: duration)
                case .endTime:
                    clipRange = try ClipRange(start: startTime, endTime: duration)
                }
            } catch {
                appendLog("Clip range must be valid. Use SS, MM:SS, or HH:MM:SS, and make sure the end is after the start.\n")
                status = "Invalid clip time"
                progressLabel = "Invalid clip time"
                return
            }
        } else {
            clipRange = nil
        }

        let requests: [DownloadRequest]
        do {
            requests = try parsedURLs.urls.map { url in
                try DownloadRequest(
                    url: url,
                    mode: mode,
                    resolution: selectedResolution,
                    outputDirectory: outputDirectory,
                    clipRange: clipRange
                )
            }
        } catch {
            appendLog("Could not prepare downloads: \(error.localizedDescription)\n")
            status = "Invalid request"
            progressLabel = "Invalid request"
            return
        }

        let batch = DownloadBatch(requests: requests, continueOnFailure: true)
        let downloader = BatchDownloader(ytDlpPath: ytDlpPath, ffmpegPath: ffmpegPath)
        activeDownloader = downloader

        isRunning = true
        totalItems = requests.count
        status = requests.count == 1 ? (downloadFullVideo ? "Downloading full video" : "Downloading clip") : "Downloading \(requests.count) items"
        progressLabel = "Starting"
        appendLog("Prepared \(requests.count) download\(requests.count == 1 ? "" : "s").\n")

        let summary = await downloader.run(batch: batch) { [weak self] event in
            Task { @MainActor in
                self?.handleDownloadEvent(event)
            }
        }

        isRunning = false
        activeDownloader = nil
        activeItemIndex = nil

        if summary.cancelled > 0 {
            status = "Stopped"
            progressLabel = "Stopped"
            appendLog("\nStopped. \(summary.succeeded) succeeded, \(summary.failed) failed, \(summary.cancelled) cancelled.\n")
        } else if summary.failed > 0 {
            status = "Completed with failures"
            progressLabel = "\(summary.succeeded)/\(summary.results.count) succeeded"
            appendLog("\nCompleted with failures. \(summary.succeeded) succeeded, \(summary.failed) failed.\n")
        } else {
            status = "Done"
            progressFraction = 1
            progressLabel = "100%"
            appendLog("\nDone. Saved to: \(outputDirectory.path)\n")
        }
    }

    func stopDownload() {
        guard isRunning else { return }
        status = "Stopping"
        progressLabel = "Stopping"
        activeDownloader?.cancel()
        appendLog("\nStopping download...\n")
    }

    private func handleDownloadEvent(_ event: DownloadEvent) {
        switch event.type {
        case "batch_started":
            totalItems = event.total ?? 0
        case "item_started":
            activeItemIndex = event.index
            progressFraction = nil
            progressLabel = itemProgressPrefix(for: event.index) ?? "Starting"
            if let url = event.url {
                appendLog("\n[\((event.index ?? 0) + 1)/\(max(totalItems, 1))] \(url)\n")
            }
        case "progress":
            progressFraction = event.fraction
            progressLabel = [itemProgressPrefix(for: event.index), event.label]
                .compactMap { $0 }
                .joined(separator: " · ")
        case "log":
            if let message = event.message {
                handleProcessOutput(message)
            }
        case "item_completed":
            appendLog("\nItem \((event.index ?? 0) + 1) completed.\n")
        case "item_failed":
            appendLog("\nItem \((event.index ?? 0) + 1) failed: \(event.message ?? "Unknown error")\n")
        case "item_cancelled":
            appendLog("\nItem \((event.index ?? 0) + 1) cancelled.\n")
        default:
            break
        }
    }

    private func itemProgressPrefix(for index: Int?) -> String? {
        guard let index, totalItems > 1 else { return nil }
        return "Item \(index + 1)/\(totalItems)"
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
        log += text.replacingOccurrences(of: "\r", with: "\n")
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
