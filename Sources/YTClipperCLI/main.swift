import Foundation
import YTClipperCore

@main
struct YTClipperCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())

        guard arguments.count == 3,
              arguments[0] == "run",
              arguments[1] == "--manifest" else {
            FileHandle.standardError.writeText("""
            Usage:
              ytclipper-cli run --manifest <path|->

            """)
            exit(2)
        }

        let manifestPath = arguments[2]
        let manifestData: Data

        do {
            if manifestPath == "-" {
                manifestData = FileHandle.standardInput.readDataToEndOfFile()
            } else {
                manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
            }
        } catch {
            FileHandle.standardError.writeText("Could not read manifest: \(error.localizedDescription)\n")
            exit(2)
        }

        let batch: DownloadBatch
        do {
            batch = try AgentManifestDecoder.decode(manifestData)
        } catch {
            FileHandle.standardError.writeText("Invalid manifest: \(error.localizedDescription)\n")
            exit(2)
        }

        guard let ytDlpPath = HelperLocator.findExecutable(named: "yt-dlp") else {
            FileHandle.standardError.writeText("Missing yt-dlp. Install it with: brew install yt-dlp\n")
            exit(3)
        }

        guard let ffmpegPath = HelperLocator.findExecutable(named: "ffmpeg") else {
            FileHandle.standardError.writeText("Missing ffmpeg. Install it with: brew install ffmpeg\n")
            exit(3)
        }

        let downloader = BatchDownloader(ytDlpPath: ytDlpPath, ffmpegPath: ffmpegPath)
        let outputLock = NSLock()

        signal(SIGINT, SIG_IGN)
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signalSource.setEventHandler {
            downloader.cancel()
        }
        signalSource.resume()

        let summary = await downloader.run(batch: batch) { event in
            guard let data = try? JSONEncoder().encode(event),
                  let line = String(data: data, encoding: .utf8) else {
                return
            }
            outputLock.lock()
            defer { outputLock.unlock() }
            FileHandle.standardOutput.writeText(line + "\n")
        }

        signalSource.cancel()

        if summary.cancelled > 0 {
            exit(130)
        }

        exit(summary.failed > 0 ? 1 : 0)
    }
}

private extension FileHandle {
    func writeText(_ text: String) {
        if let data = text.data(using: .utf8) {
            write(data)
        }
    }
}
