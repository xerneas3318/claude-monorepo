import FirebaseFirestore
import Foundation

@MainActor
final class FilesStore: ObservableObject {
    @Published private(set) var files: [BrainFile] = []
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var errorMessage: String?

    private var listener: ListenerRegistration?
    private let userId: String

    init(userId: String) { self.userId = userId }

    func start() {
        guard listener == nil else { return }
        listener = Firestore.firestore()
            .collection("users").document(userId)
            .collection("files")
            .order(by: "path")
            .addSnapshotListener { [weak self] snap, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.errorMessage = nil
                    self.files = (snap?.documents ?? []).compactMap { doc in
                        let d = doc.data()
                        guard let path = d["path"] as? String else { return nil }
                        return BrainFile(
                            id: doc.documentID,
                            path: path,
                            title: d["title"] as? String,
                            raw: d["raw"] as? String ?? "",
                            kind: d["kind"] as? String ?? "raw",
                            taskCount: d["task_count"] as? Int ?? 0,
                            size: d["size"] as? Int ?? 0
                        )
                    }
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    var groupedByFolder: [(folder: String, files: [BrainFile])] {
        var seen: [String] = []
        var bucket: [String: [BrainFile]] = [:]
        for f in files {
            let key = f.folder.isEmpty ? "(root)" : f.folder
            if bucket[key] == nil { seen.append(key) }
            bucket[key, default: []].append(f)
        }
        return seen.map { ($0, bucket[$0] ?? []) }
    }
}
