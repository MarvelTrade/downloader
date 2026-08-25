import Darwin
import Foundation

enum HostArchitecture {
    static var machine: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { chars in
                String(cString: chars)
            }
        }
    }

    /// Values shown in About: Apple Silicon or Intel.
    static var displayName: String {
        switch machine {
        case "arm64":
            return "Apple Silicon"
        case "x86_64":
            return "Intel"
        default:
            return machine
        }
    }

    static func supportsCurrentArchitecture(_ url: URL) -> Bool {
        let archs = machOArchitectures(in: url)
        guard !archs.isEmpty else { return false }
        return archs.contains(machine)
    }

    static func machOArchitectures(in url: URL) -> Set<String> {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let prefix = try? handle.read(upToCount: 8), prefix.count == 8 else { return [] }
        let bytes = [UInt8](prefix)

        if bytes.starts(with: [0x23, 0x21]) {
            return []
        }

        let fat32: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE]
        let fat64: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBF]
        if bytes.starts(with: fat32) || bytes.starts(with: fat64) {
            let isFat64 = bytes.starts(with: fat64)
            let count = Int(readUInt32BE(bytes, offset: 4))
            let entrySize = isFat64 ? 32 : 20
            let needed = 8 + (count * entrySize)
            try? handle.seek(toOffset: 0)
            guard let header = try? handle.read(upToCount: needed), header.count >= needed else { return [] }
            var result: Set<String> = []
            var offset = 8
            for _ in 0..<count {
                if let name = cpuTypeName(Int32(bitPattern: readUInt32BE([UInt8](header), offset: offset))) {
                    result.insert(name)
                }
                offset += entrySize
            }
            return result
        }

        let macho64LE: [UInt8] = [0xCF, 0xFA, 0xED, 0xFE]
        let macho32LE: [UInt8] = [0xCE, 0xFA, 0xED, 0xFE]
        let macho64BE: [UInt8] = [0xFE, 0xED, 0xFA, 0xCF]
        let macho32BE: [UInt8] = [0xFE, 0xED, 0xFA, 0xCE]
        let cputype: Int32
        if bytes.starts(with: macho64LE) || bytes.starts(with: macho32LE) {
            cputype = Int32(littleEndian: readInt32LE(bytes, offset: 4))
        } else if bytes.starts(with: macho64BE) || bytes.starts(with: macho32BE) {
            cputype = Int32(bitPattern: readUInt32BE(bytes, offset: 4))
        } else {
            return []
        }
        if let name = cpuTypeName(cputype) {
            return [name]
        }
        return []
    }

    private static func cpuTypeName(_ cpuType: Int32) -> String? {
        let abi64: Int32 = 0x01000000
        let x86: Int32 = 7
        let arm: Int32 = 12
        switch cpuType {
        case abi64 | x86:
            return "x86_64"
        case abi64 | arm:
            return "arm64"
        default:
            return nil
        }
    }

    private static func readUInt32BE(_ bytes: [UInt8], offset: Int) -> UInt32 {
        guard bytes.count >= offset + 4 else { return 0 }
        return (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
    }

    private static func readInt32LE(_ bytes: [UInt8], offset: Int) -> Int32 {
        guard bytes.count >= offset + 4 else { return 0 }
        return Int32(bitPattern:
            UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
        )
    }
}
