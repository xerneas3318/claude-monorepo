import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var store: FilesStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showTalk = false
    @State private var search = ""

    init(userId: String) {
        _store = StateObject(wrappedValue: FilesStore(userId: userId))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Browse")
                .searchable(text: $search, prompt: "Find a file")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showTalk = true } label: { Image(systemName: "mic.circle") }
                            .accessibilityLabel("Talk to Claude")
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
        .sheet(isPresented: $showTalk) { TalkView() }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.files.isEmpty {
            ProgressView().controlSize(.large)
        } else if let err = store.errorMessage {
            ContentUnavailableView("Couldn't load files",
                systemImage: "exclamationmark.triangle",
                description: Text(err))
        } else if filteredGroups.isEmpty {
            ContentUnavailableView.search
        } else {
            List {
                ForEach(filteredGroups, id: \.folder) { group in
                    Section(group.folder) {
                        ForEach(group.files) { file in
                            NavigationLink(value: file) {
                                FileRow(file: file)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationDestination(for: BrainFile.self) { FileDetailView(file: $0) }
        }
    }

    private var filteredGroups: [(folder: String, files: [BrainFile])] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let groups = store.groupedByFolder
        guard !q.isEmpty else { return groups }
        return groups.compactMap { group in
            let hits = group.files.filter {
                $0.path.lowercased().contains(q)
                    || ($0.title?.lowercased().contains(q) ?? false)
                    || $0.raw.lowercased().contains(q)
            }
            return hits.isEmpty ? nil : (group.folder, hits)
        }
    }
}

private struct FileRow: View {
    let file: BrainFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.body)
                if let title = file.title, title != file.fileName {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if file.taskCount > 0 {
                Text("\(file.taskCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
        }
    }

    private var icon: String {
        switch file.kind {
        case "today": "checklist"
        case "future": "calendar.badge.clock"
        default:       "doc.text"
        }
    }
}
