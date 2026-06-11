import FirebaseFirestore
import Foundation

@MainActor
final class TodayStore: ObservableObject {
    @Published private(set) var title: String = ""
    @Published private(set) var tasks: [BrainTask] = []
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var errorMessage: String?

    private var fileListener: ListenerRegistration?
    private var tasksListener: ListenerRegistration?

    // The signed-in Firebase UID. The daemon must be configured with the same
    // value (see sync-daemon/config.js -> userId) so they read/write the same
    // subtree.
    private let userId: String

    init(userId: String) {
        self.userId = userId
    }

    func start() {
        guard fileListener == nil else { return }
        let fileRef = Firestore.firestore()
            .collection("users").document(userId)
            .collection("files").document("daily__today.md")

        fileListener = fileRef.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                self.title = (snapshot?.data()?["title"] as? String) ?? ""
            }
        }

        tasksListener = fileRef.collection("tasks")
            .order(by: "order")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.errorMessage = nil
                    self.tasks = (snapshot?.documents ?? []).map { doc in
                        let d = doc.data()
                        let notesRaw = d["notes"] as? String
                        let notes = (notesRaw?.isEmpty == false) ? notesRaw : nil
                        return BrainTask(
                            id: doc.documentID,
                            category: d["category"] as? String ?? "Uncategorized",
                            text: d["text"] as? String ?? "",
                            checked: d["checked"] as? Bool ?? false,
                            order: d["order"] as? Int ?? 0,
                            date: d["date"] as? String,
                            notes: notes
                        )
                    }
                }
            }
    }

    func stop() {
        fileListener?.remove()
        tasksListener?.remove()
        fileListener = nil
        tasksListener = nil
    }

    func toggle(_ task: BrainTask) {
        let docRef = Firestore.firestore()
            .collection("users").document(userId)
            .collection("files").document("daily__today.md")
            .collection("tasks").document(task.id)

        docRef.updateData([
            "checked": !task.checked,
            "updated_at": FieldValue.serverTimestamp(),
            "updated_by": "phone",
        ]) { [weak self] error in
            if let error {
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                    print("[TodayStore] toggle failed: \(error)")
                }
            }
        }
    }

    // Reorder tasks within a single category. SwiftUI passes section-local
    // offsets directly from .onMove.
    func reorder(in category: String, from source: IndexSet, to destination: Int) {
        var groups = groupedBuckets()
        guard var section = groups.buckets[category] else { return }
        section.move(fromOffsets: source, toOffset: destination)
        groups.buckets[category] = section
        publishRewrite(flatten(groups))
    }

    // Update text / notes / category of a single task. If `newCategory`
    // doesn't exist yet, it's appended as a new section. The task keeps its
    // position within its (possibly new) section.
    func updateTask(
        _ task: BrainTask,
        text newText: String,
        notes newNotes: String?,
        category newCategory: String
    ) {
        let categoryChanged = newCategory != task.category
        let updated = BrainTask(
            id: task.id,
            category: newCategory,
            text: newText,
            checked: task.checked,
            order: task.order,
            date: task.date,
            notes: newNotes
        )
        var groups = groupedBuckets()
        if categoryChanged {
            if var oldSection = groups.buckets[task.category] {
                oldSection.removeAll { $0.id == task.id }
                if oldSection.isEmpty {
                    groups.buckets.removeValue(forKey: task.category)
                    groups.order.removeAll { $0 == task.category }
                } else {
                    groups.buckets[task.category] = oldSection
                }
            }
            if groups.buckets[newCategory] != nil {
                groups.buckets[newCategory]?.append(updated)
            } else {
                groups.buckets[newCategory] = [updated]
                groups.order.append(newCategory)
            }
        } else {
            if var section = groups.buckets[task.category],
               let idx = section.firstIndex(where: { $0.id == task.id }) {
                section[idx] = updated
                groups.buckets[task.category] = section
            }
        }
        publishRewrite(flatten(groups))
    }

    // Remove a task entirely. If its section becomes empty, drop the section.
    func deleteTask(_ task: BrainTask) {
        var groups = groupedBuckets()
        guard var section = groups.buckets[task.category] else { return }
        section.removeAll { $0.id == task.id }
        if section.isEmpty {
            groups.buckets.removeValue(forKey: task.category)
            groups.order.removeAll { $0 == task.category }
        } else {
            groups.buckets[task.category] = section
        }
        publishRewrite(flatten(groups))
    }

    // Move a single task into a different existing (or new) category. The
    // task lands at the end of the destination section.
    func moveTask(_ task: BrainTask, toCategory newCategory: String) {
        guard task.category != newCategory else { return }
        var groups = groupedBuckets()
        if var oldSection = groups.buckets[task.category] {
            oldSection.removeAll { $0.id == task.id }
            if oldSection.isEmpty {
                groups.buckets.removeValue(forKey: task.category)
                groups.order.removeAll { $0 == task.category }
            } else {
                groups.buckets[task.category] = oldSection
            }
        }
        let moved = BrainTask(
            id: task.id,
            category: newCategory,
            text: task.text,
            checked: task.checked,
            order: task.order,
            date: task.date,
            notes: task.notes
        )
        if groups.buckets[newCategory] != nil {
            groups.buckets[newCategory]?.append(moved)
        } else {
            groups.buckets[newCategory] = [moved]
            groups.order.append(newCategory)
        }
        publishRewrite(flatten(groups))
    }

    var groupedByCategory: [(category: String, tasks: [BrainTask])] {
        let g = groupedBuckets()
        return g.order.map { ($0, g.buckets[$0] ?? []) }
    }

    var categories: [String] { groupedBuckets().order }

    private func groupedBuckets() -> (order: [String], buckets: [String: [BrainTask]]) {
        var seen: [String] = []
        var bucket: [String: [BrainTask]] = [:]
        for task in tasks {
            if bucket[task.category] == nil { seen.append(task.category) }
            bucket[task.category, default: []].append(task)
        }
        return (seen, bucket)
    }

    private func flatten(_ groups: (order: [String], buckets: [String: [BrainTask]])) -> [BrainTask] {
        groups.order.flatMap { groups.buckets[$0] ?? [] }
    }

    // Optimistically update local state, render today.md, write `raw` to the
    // file doc. Daemon's file-level watcher writes to disk + re-parses, which
    // refreshes `tasks` with canonical `order` values shortly after.
    private func publishRewrite(_ newOrder: [BrainTask]) {
        tasks = newOrder
        let markdown = renderTodayMarkdown(title: title, tasks: newOrder)
        let docRef = Firestore.firestore()
            .collection("users").document(userId)
            .collection("files").document("daily__today.md")
        docRef.updateData([
            "raw": markdown,
            "size": markdown.utf8.count,
            "task_count": newOrder.count,
            "parsed_at": FieldValue.serverTimestamp(),
            "updated_by": "phone",
        ]) { [weak self] error in
            if let error {
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                    print("[TodayStore] rewrite failed: \(error)")
                }
            }
        }
    }
}

// Mirror of sync-daemon/scripts/rotate-today.js renderToday(). Round-trips
// indented notes under each task as "  <line>".
private func renderTodayMarkdown(title: String, tasks: [BrainTask]) -> String {
    var seen: [String] = []
    var bucket: [String: [BrainTask]] = [:]
    for t in tasks {
        if bucket[t.category] == nil { seen.append(t.category) }
        bucket[t.category, default: []].append(t)
    }
    var lines: [String] = ["# \(title)", ""]
    for cat in seen {
        lines.append("## \(cat)")
        for t in bucket[cat] ?? [] {
            let mark = t.checked ? "x" : " "
            lines.append("- [\(mark)] \(t.text)")
            if let notes = t.notes, !notes.isEmpty {
                for noteLine in notes.split(separator: "\n", omittingEmptySubsequences: false) {
                    lines.append(noteLine.isEmpty ? "" : "  \(noteLine)")
                }
            }
        }
        lines.append("")
    }
    return lines.joined(separator: "\n")
}
