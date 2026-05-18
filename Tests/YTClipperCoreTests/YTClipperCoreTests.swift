import Foundation
import Testing
@testable import YTClipperCore

@Suite
struct YTClipperCoreTests {
    @Test
    func testTimecodeParserAcceptsSecondsMinutesAndHours() {
        #expect(TimecodeParser.seconds(from: "75") == 75)
        #expect(TimecodeParser.seconds(from: "01:15") == 75)
        #expect(TimecodeParser.seconds(from: "01:02:03") == 3723)
        #expect(TimecodeParser.string(from: 3723) == "01:02:03")
        #expect(TimecodeParser.seconds(from: "01:99") == nil)
    }

    @Test
    func testURLListParserTrimsBlankLinesAndRejectsInvalidURLs() {
        let result = URLListParser.parse("""

        https://www.youtube.com/watch?v=abc123
        not-a-url
        https://youtu.be/xyz987

        """)

        #expect(result.urls == [
            "https://www.youtube.com/watch?v=abc123",
            "https://youtu.be/xyz987"
        ])
        #expect(result.invalidEntries == ["not-a-url"])
    }

    @Test
    func testDownloadArgumentsBuildFullVideoCommand() throws {
        let request = try DownloadRequest(
            url: "https://youtu.be/abc123",
            mode: .full,
            resolution: .p1080,
            outputDirectory: URL(fileURLWithPath: "/tmp/out"),
            clipRange: nil
        )

        let args = request.ytDlpArguments(ffmpegPath: "/opt/homebrew/bin/ffmpeg")

        #expect(args.contains("--no-playlist"))
        #expect(args.contains("bv*[height<=1080]+ba/b[height<=1080]/best[height<=1080]"))
        #expect(!args.contains("--download-sections"))
        #expect(args.last == "https://youtu.be/abc123")
    }

    @Test
    func testDownloadArgumentsBuildClipCommand() throws {
        let request = try DownloadRequest(
            url: "https://www.youtube.com/watch?v=abc123",
            mode: .clip,
            resolution: .best,
            outputDirectory: URL(fileURLWithPath: "/tmp/out"),
            clipRange: ClipRange(start: "00:01:15", duration: "00:00:30")
        )

        let args = request.ytDlpArguments(ffmpegPath: "/usr/local/bin/ffmpeg")

        let sectionIndex = try #require(args.firstIndex(of: "--download-sections"))
        #expect(args[sectionIndex + 1] == "*00:01:15-00:01:45")
        #expect(args.contains("--force-keyframes-at-cuts"))
    }

    @Test
    func testProgressParserExtractsLatestDownloadPercentage() {
        let progress = DownloadProgressParser.parse("[download]  12.5% of 10.00MiB\n[download]  42.1% of 10.00MiB")

        #expect(abs((progress?.fraction ?? 0) - 0.421) < 0.0001)
        #expect(progress?.label == "42.1%")
    }

    @Test
    func testAgentManifestDecodesSharedSettings() throws {
        let data = """
        {
          "version": 1,
          "outputDirectory": "/tmp/out",
          "mode": "clip",
          "resolution": "p1080",
          "clip": { "start": "00:01:15", "duration": "00:00:30" },
          "continueOnFailure": true,
          "jobs": [
            { "url": "https://youtu.be/abc123" },
            { "url": "https://www.youtube.com/watch?v=xyz987" }
          ]
        }
        """.data(using: .utf8)!

        let batch = try AgentManifestDecoder.decode(data)

        #expect(batch.requests.count == 2)
        #expect(batch.requests[0].mode == .clip)
        #expect(batch.requests[0].resolution == .p1080)
        #expect(batch.continueOnFailure)
    }

    @Test
    func testAgentManifestRejectsUnsupportedVersion() {
        let data = """
        {
          "version": 2,
          "outputDirectory": "/tmp/out",
          "jobs": [
            { "url": "https://youtu.be/abc123" }
          ]
        }
        """.data(using: .utf8)!

        #expect(throws: DownloadValidationError.unsupportedManifestVersion(2)) {
            try AgentManifestDecoder.decode(data)
        }
    }

    @Test
    func testBatchRunnerContinuesAfterFailureAndSummarizes() async throws {
        let requests = try [
            DownloadRequest(url: "https://youtu.be/ok", mode: .full, resolution: .best, outputDirectory: URL(fileURLWithPath: "/tmp/out"), clipRange: nil),
            DownloadRequest(url: "https://youtu.be/fail", mode: .full, resolution: .best, outputDirectory: URL(fileURLWithPath: "/tmp/out"), clipRange: nil),
            DownloadRequest(url: "https://youtu.be/ok2", mode: .full, resolution: .best, outputDirectory: URL(fileURLWithPath: "/tmp/out"), clipRange: nil)
        ]
        let batch = DownloadBatch(requests: requests, continueOnFailure: true)
        let runner = FakeCommandRunner(results: [
            .success,
            .failure("network failed"),
            .success
        ])
        let executor = BatchDownloader(
            ytDlpPath: "/usr/local/bin/yt-dlp",
            ffmpegPath: "/usr/local/bin/ffmpeg",
            commandRunner: runner
        )

        let summary = await executor.run(batch: batch) { _ in }

        #expect(summary.succeeded == 2)
        #expect(summary.failed == 1)
        #expect(summary.cancelled == 0)
        #expect(await runner.invocationCount == 3)
    }
}

private actor FakeCommandRunner: CommandRunning {
    private var results: [ProcessRunResult]
    private(set) var invocations: [[String]] = []

    init(results: [ProcessRunResult]) {
        self.results = results
    }

    func run(
        executable: String,
        arguments: [String],
        controller: ProcessController,
        onOutput: @escaping @Sendable (String) -> Void
    ) async -> ProcessRunResult {
        invocations.append(arguments)
        let result = results.removeFirst()
        return result
    }

    var invocationCount: Int {
        invocations.count
    }
}
