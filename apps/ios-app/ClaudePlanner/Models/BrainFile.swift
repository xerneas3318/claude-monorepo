import Foundation

struct BrainFile: Identifiable, Hashable {
    let id: String              // Firestore doc id, e.g. "daily__today.md"
    let path: String            // "daily/today.md"
    let title: String?
    let raw: String
    let kind: String            // "today" | "future" | "raw"
    let taskCount: Int
    let size: Int

    var folder: String {
        let parts = path.split(separator: "/")
        return parts.dropLast().joined(separator: "/")
    }
    var fileName: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
    var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        return fileName.replacingOccurrences(of: ".md", with: "")
    }
}
