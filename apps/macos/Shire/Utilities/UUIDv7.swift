import Foundation

/// UUIDv7 generator — sortable by creation time
enum UUIDv7 {
    static func generate() -> String {
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)

        // 48 bits of timestamp
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = UInt8((timestamp >> 40) & 0xFF)
        bytes[1] = UInt8((timestamp >> 32) & 0xFF)
        bytes[2] = UInt8((timestamp >> 24) & 0xFF)
        bytes[3] = UInt8((timestamp >> 16) & 0xFF)
        bytes[4] = UInt8((timestamp >> 8) & 0xFF)
        bytes[5] = UInt8(timestamp & 0xFF)

        // Random bytes for the rest
        var randomBytes = [UInt8](repeating: 0, count: 10)
        _ = SecRandomCopyBytes(kSecRandomDefault, 10, &randomBytes)
        for i in 0..<10 {
            bytes[6 + i] = randomBytes[i]
        }

        // Set version (7) and variant (10xx)
        bytes[6] = (bytes[6] & 0x0F) | 0x70  // version 7
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // variant 10xx

        // Format as UUID string
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let uuid = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
        return uuid
    }
}
