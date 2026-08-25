import Foundation

struct ProcessResult: Sendable {
    let exitCode: Int32
    let terminationReason: Process.TerminationReason
    let stdout: String
    let stderr: String
}

enum ProcessRunner {
    static func run(
        executable: URL,
        arguments: [String],
        extraPATH: [String],
        currentDirectory: URL? = nil,
        session: CancellableSession? = nil,
        onStdout: (@Sendable (String) -> Void)? = nil,
        onStderr: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        try session?.throwIfCancelled()

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.environment = BinaryLocator.isolatedEnvironment(extraPATH: extraPATH)
        process.qualityOfService = .userInitiated

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        let collector = OutputCollector()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { await collector.appendStdout(chunk) }
            onStdout?(chunk)
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { await collector.appendStderr(chunk) }
            onStderr?(chunk)
        }

        DebugLog.info("Launching \(executable.lastPathComponent) with arguments: \(arguments.joined(separator: " "))")

        do {
            try process.run()
        } catch {
            DebugLog.error("Failed to launch \(executable.path): \(error.localizedDescription)")
            throw DownloadError.downloadFailed
        }

        try session?.register(process)
        if session?.isCancelled == true {
            ProcessKiller.terminateTree(process)
            throw DownloadError.cancelled
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        let remainingOut = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let remainingErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if let chunk = String(data: remainingOut, encoding: .utf8), !chunk.isEmpty {
            await collector.appendStdout(chunk)
            onStdout?(chunk)
        }
        if let chunk = String(data: remainingErr, encoding: .utf8), !chunk.isEmpty {
            await collector.appendStderr(chunk)
            onStderr?(chunk)
        }

        let output = await collector.snapshot()
        DebugLog.info("\(executable.lastPathComponent) exited with code \(process.terminationStatus)")

        if session?.isCancelled == true {
            throw DownloadError.cancelled
        }

        return ProcessResult(
            exitCode: process.terminationStatus,
            terminationReason: process.terminationReason,
            stdout: output.stdout,
            stderr: output.stderr
        )
    }
}

private actor OutputCollector {
    private var stdout = ""
    private var stderr = ""

    func appendStdout(_ chunk: String) {
        stdout += chunk
    }

    func appendStderr(_ chunk: String) {
        stderr += chunk
    }

    func snapshot() -> (stdout: String, stderr: String) {
        (stdout, stderr)
    }
}
