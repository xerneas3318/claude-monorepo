import SwiftUI

struct EditTaskSheet: View {
    let original: BrainTask
    let existingCategories: [String]
    let onSave: (_ text: String, _ notes: String?, _ category: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var notes: String
    @State private var category: String
    @State private var customCategoryMode: Bool
    @State private var newCategoryDraft: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case text, notes, newCategory }

    init(
        task: BrainTask,
        existingCategories: [String],
        onSave: @escaping (_ text: String, _ notes: String?, _ category: String) -> Void
    ) {
        self.original = task
        self.existingCategories = existingCategories
        self.onSave = onSave
        _text = State(initialValue: task.text)
        _notes = State(initialValue: task.notes ?? "")
        _category = State(initialValue: task.category)
        _customCategoryMode = State(initialValue: !existingCategories.contains(task.category))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Description", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focusedField, equals: .text)
                }
                Section("Category") {
                    if customCategoryMode {
                        TextField("New category", text: $newCategoryDraft)
                            .focused($focusedField, equals: .newCategory)
                            .submitLabel(.done)
                            .autocorrectionDisabled()
                        Button("Pick existing") { customCategoryMode = false }
                            .font(.subheadline)
                    } else {
                        Picker("Category", selection: $category) {
                            ForEach(allCategoryOptions, id: \.self) { Text($0).tag($0) }
                        }
                        Button("New category…") {
                            newCategoryDraft = ""
                            customCategoryMode = true
                            focusedField = .newCategory
                        }
                        .font(.subheadline)
                    }
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .focused($focusedField, equals: .notes)
                    Text("Markdown supported. Shows under the task when expanded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear { focusedField = .text }
        }
    }

    private var allCategoryOptions: [String] {
        var seen = existingCategories
        if !seen.contains(category) { seen.insert(category, at: 0) }
        return seen
    }

    private var resolvedCategory: String {
        let cat = customCategoryMode ? newCategoryDraft : category
        return cat.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !resolvedCategory.isEmpty
    }

    private func save() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNotes: String? = trimmedNotes.isEmpty ? nil : notes
        onSave(trimmedText, finalNotes, resolvedCategory)
        dismiss()
    }
}
