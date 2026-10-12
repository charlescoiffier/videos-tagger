import SwiftUI
import VideoTagCore

struct VideoRow: View {
    let video: Video
    let tags: [TagDef]
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().strokeBorder(video.reviewed ? Theme.accent : Color.secondary.opacity(0.5), lineWidth: 1.5)
                    .background(Circle().fill(video.reviewed ? Theme.accent : .clear))
                if video.reviewed {
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(width: 16, height: 16)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(video.reviewed ? .secondary : .primary)
                let meta = [video.date, video.author].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                let subtitle = meta.isEmpty ? video.folder : meta
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                let on = tags.filter { video.tags[$0.key] == true }
                if !on.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(on) { t in
                            LabelChip(text: t.label, color: t.finder?.color.swiftUI ?? Theme.accent)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(selected ? Theme.accent.opacity(0.12) : (hovering ? Theme.hover : .clear),
                    in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
