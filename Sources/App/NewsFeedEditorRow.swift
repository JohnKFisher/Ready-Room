import SwiftUI
import ReadyRoomCore

struct NewsFeedEditorRow: View {
    @Binding var feed: ConfiguredNewsFeed
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(feed.isUserAdded ? "Manual Feed" : "Starter Feed")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Remove", role: .destructive, action: remove)
                    .help("Remove this news feed")
            }
            TextField("Feed label", text: $feed.label)
                .textFieldStyle(.roundedBorder)
            TextField("Feed URL", text: $feed.feedURLString)
                .textFieldStyle(.roundedBorder)
            HStack {
                Picker("Category", selection: $feed.category) {
                    ForEach(NewsCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                Picker("Story Lane", selection: $feed.storyLane) {
                    ForEach(NewsStoryLane.allCases, id: \.self) { lane in
                        Text(lane.displayName).tag(lane)
                    }
                }
                Toggle("Enabled", isOn: $feed.isEnabled)
            }
            HStack {
                Text("Source Priority")
                    .font(.caption.weight(.semibold))
                Slider(value: $feed.sourcePriority, in: 0.5...2.0, step: 0.05)
                    .accessibilityLabel("Source Priority")
                Text(String(format: "%.2f", feed.sourcePriority))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let statusNote = feed.statusNote {
                Text(statusNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}
