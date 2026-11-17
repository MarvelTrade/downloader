import Darwin
import Foundation

final class CancellableSession: @unchecked Sendable {
    private let lock = NSLock()
    private var processes: [Process] = []
    private var networkTasks: [URLSessionTask] = []
    private var cancelledFlag = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledFlag
    }

    func register(_ process: Process) throws {
        lock.lock()
        defer { lock.unlock() }
        if cancelledFlag {
            throw DownloadError.cancelled
        }
        processes.append(process)
    }

    func register(_ task: URLSessionTask) throws {
        lock.lock()
        defer { lock.unlock() }
        if cancelledFlag {
            task.cancel()
            throw DownloadError.cancelled
        }
        networkTasks.append(task)
    }

    func unregister(_ task: URLSessionTask) {
        lock.lock()
        networkTasks.removeAll { $0 === task }
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelledFlag = true
        let snapshot = processes
        let networkSnapshot = networkTasks
        lock.unlock()
        for process in snapshot {
            ProcessKiller.terminateTree(process)
        }
        for task in networkSnapshot {
            task.cancel()
        }
    }

    func throwIfCancelled() throws {
        if isCancelled {
            throw DownloadError.cancelled
        }
    }
}

enum ProcessKiller {
    static func terminateTree(_ process: Process) {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        let descendants = collectDescendants(of: pid)

        kill(pid, SIGTERM)
        for child in descendants {
            kill(child, SIGTERM)
        }

        let deadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            for child in collectDescendants(of: pid) {
                kill(child, SIGKILL)
            }
            kill(pid, SIGKILL)
            process.terminate()
        }
    }

    private static func collectDescendants(of pid: pid_t) -> [pid_t] {
        var result: [pid_t] = []
        var buffer = [pid_t](repeating: 0, count: 256)
        let bytes = proc_listchildpids(pid, &buffer, Int32(MemoryLayout<pid_t>.stride * buffer.count))
        let count = max(0, Int(bytes) / MemoryLayout<pid_t>.stride)
        for index in 0..<count {
            let child = buffer[index]
            guard child > 0 else { continue }
            result.append(child)
            result.append(contentsOf: collectDescendants(of: child))
        }
        return result
    }
}
