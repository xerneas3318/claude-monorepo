import MarkdownUI
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var router: AppRouter
    @StateObject private var store: TodayStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var expanded: Set<String> = []
    @State private var editingTask: BrainTask?

    init(userId: String) {
        _store = StateObject(wrappedValue: TodayStore(userId: userId))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(store.title.isEmpty ? "Today" : store.title)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { router.requestTalk() } label: { Image(systemName: "mic.circle") }
                            .accessibilityLabel("Talk to Claude")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Sign Out", role: .destructive, action: auth.signOut)
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                }
        }
        .onAppear { store.start() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:    store.start()
            case .background: store.stop()
            default: break
            }
        }
        .sheet(isPresented: $router.showTalk) { TalkView() }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(
                task: task,
                existingCategories: store.categories
            ) { newText, newNotes, newCategory in
                store.updateTask(task, text: newText, notes: newNotes, category: newCategory)
            }
        }
        .onOpenURL { url in
            if url.scheme == "claudeplanner" && url.host == "talk" { router.requestTalk() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading {
            ProgressView().controlSize(.large)
        } else if let error = store.errorMessage {
            ContentUnavailableView("Couldn't load today",
                systemImage: "exclamationmark.triangle",
                description: Text(error))
        } else if store.tasks.isEmpty {
            ContentUnavailableView("Nothing today",
                systemImage: "checkmark.circle",
                description: Text("today.md has no tasks yet."))
        } else {
            List {
                summarySection
                ForEach(store.groupedByCategory, id: \.category) { group in
                    Section(group.category) {
                        ForEach(group.tasks) { task in
                            TaskRow(
                                task: task,
                                isExpanded: expanded.contains(task.id),
                                onToggle: { store.toggle(task) },
                                onSelect: {
                                    guard task.hasNotes else { return }
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        if expanded.contains(task.id) { expanded.remove(task.id) }
                                        else { expanded.insert(task.id) }
                                    }
                                }
                            )
                            .contextMenu {
                                Button {
                                    editingTask = task
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                let others = store.categories.filter { $0 != task.category }
                                if !others.isEmpty {
                                    Menu("Move to…") {
                                        ForEach(others, id: \.self) { cat in
                                            Button(cat) { store.moveTask(task, toCategory: cat) }
                                        }
                                    }
                                }
                                Button(role: .destructive) {
                                    store.deleteTask(task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.deleteTask(task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingTask = task
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onMove { source, destination in
                            store.reorder(in: group.category, from: source, to: destination)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var summarySection: some View {
        let remaining = store.tasks.filter { !$0.checked }.count
        let done = store.tasks.count - remaining
        return Section {
            HStack {
                Image(systemName: "circle.dotted").foregroundStyle(.secondary)
                Text("\(remaining) remaining · \(done) done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
        .listSectionSpacing(.compact)
    }
}

struct TaskRow: View {
    let task: BrainTask
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: task.checked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.checked ? Color.accentColor : Color.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Text(task.text)
                    .strikethrough(task.checked, color: .secondary)
                    .foregroundStyle(task.checked ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if task.hasNotes {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            if isExpanded, let notes = task.notes {
                Markdown(notes)
                    .markdownTextStyle(\.text) {
                        FontSize(.em(0.92))
                        ForegroundColor(.secondary)
                    }
                    .padding(.leading, 30)
                    .padding(.bottom, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}
