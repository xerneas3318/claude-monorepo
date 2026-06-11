import MarkdownUI
import SwiftUI

struct FileDetailView: View {
    let file: BrainFile
    @State private var showRaw = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(file.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Divider()
                if showRaw {
                    Text(file.raw)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Markdown(file.raw)
                        .markdownTheme(.gitHub)
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .navigationTitle(file.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRaw.toggle()
                } label: {
                    Image(systemName: showRaw ? "doc.richtext" : "chevron.left.forwardslash.chevron.right")
                }
                .accessibilityLabel(showRaw ? "Show rendered" : "Show raw")
            }
        }
    }
}
