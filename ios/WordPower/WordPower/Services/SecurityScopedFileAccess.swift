import Foundation

enum SecurityScopedFileAccess {
    static func withAccess<T>(to url: URL, operation: () throws -> T) throws -> T {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }
}
