import SwiftUI
import AppKit
import VideoTagCore

struct SorterView: View {
    @Bindable var state: AppState
    var openSettings: () -> Void = {}
    @State private var image: NSImage?
    @State private var imageMissing = false
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var basePan: CGSize = .zero

    var body: some View {
        Group {
            if let video = state.selected {
                VStack(alignment: .leading, spacing: 10) {
                    header(video)
                    planche
                    tagBar(video)
                    navBar
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .task(id: video.id) {
                    image = nil
                    imageMissing = false
                    resetZoom()
                    guard let rel = video.screen, let root = state.root else { imageMissing = true; return }
                    let url = root.appendingPathComponent(rel)
                    let data = await Task.detached { try? Data(contentsOf: url) }.value
                    let loaded = data.flatMap { NSImage(data: $0) }
                    image = loaded
                    imageMissing = loaded == nil
                }
            } else {
                ContentUnavailableView("Aucune vidéo sélectionnée", systemImage: "film")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas)
    }

    private var planche: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
                    .scaleEffect(zoom)
                    .offset(pan)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { zoom = min(max(baseZoom * $0.magnification, 1), 10) }
                            .onEnded { _ in
                                baseZoom = zoom
                                if zoom == 1 { pan = .zero; basePan = .zero }
                            })
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { g in
                                guard zoom > 1 else { return }
                                pan = CGSize(width: basePan.width + g.translation.width,
                                             height: basePan.height + g.translation.height)
                            }
                            .onEnded { _ in basePan = pan })
                    .onTapGesture(count: 2) { withAnimation(.easeOut(duration: 0.15)) { resetZoom() } }
            } else if imageMissing {
                ContentUnavailableView("Pas de planche", systemImage: "photo")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func resetZoom() {
        zoom = 1; baseZoom = 1; pan = .zero; basePan = .zero
    }

    private func header(_ v: Video) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(v.title).font(.system(size: 22, weight: .bold)).lineLimit(1)
            if v.reviewed { LabelChip(text: "revue", color: .green) }
            HStack(spacing: 8) {
                if let a = v.author, !a.isEmpty { Label(a, systemImage: "person") }
                if let d = v.date, !d.isEmpty { Label(d, systemImage: "calendar").foregroundStyle(.secondary) }
            }
            .font(.system(size: 13))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func tagBar(_ v: Video) -> some View {
        if state.config.tags.isEmpty {
            HStack {
                Text("Aucun tag défini : créez-en pour trier avec une touche de clavier et poser des étiquettes Finder.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Créer des tags…") { openSettings() }.buttonStyle(PrimaryPillStyle())
            }
        } else {
            // Hauteur bornée (3 lignes de pastilles, défilement au-delà) : un grand nombre de tags ne doit jamais
            // pousser les boutons de navigation hors de la fenêtre.
            ScrollView(.vertical, showsIndicators: false) {
                FlowLayout(spacing: 6) {
                    lockButton
                    ForEach(state.config.tags) { tag in
                        tagChip(tag, on: v.tags[tag.key] == true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 92)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Verrou des tags : activé, ni le clic ni les raccourcis clavier ne modifient les tags des vidéos.
    private var lockButton: some View {
        Button { state.tagsLocked.toggle() } label: {
            Image(systemName: state.tagsLocked ? "lock.fill" : "lock.open")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(state.tagsLocked ? Theme.accent : Color.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(state.tagsLocked ? Theme.accent.opacity(0.14) : Theme.hover))
        }
        .buttonStyle(.plain)
        .help(state.tagsLocked
              ? "Tags verrouillés : le clic et les raccourcis clavier ne modifient plus les tags. Cliquez pour déverrouiller."
              : "Tags déverrouillés. Cliquez pour verrouiller (empêche de modifier les tags par erreur).")
    }

    private func tagChip(_ tag: TagDef, on: Bool) -> some View {
        let color = tag.finder?.color.swiftUI ?? Theme.accent
        return Button { state.toggle(tag) } label: {
            HStack(spacing: 5) {
                if let s = tag.shortcut { KeyCap(text: s, onColor: on, small: true) }
                if !on, tag.finder != nil { Circle().fill(color).frame(width: 6, height: 6) }
                Text(tag.label).font(.system(size: 12, weight: .medium))
                if on { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(on ? Color.white : Color.primary)
            .background(on ? color : Color.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(on ? Color.clear : Theme.border, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(state.tagsLocked)
        .opacity(state.tagsLocked ? 0.45 : 1)
    }

    private var navBar: some View {
        ZStack {
            Button("Prochaine non revue") { state.nextUnreviewed() }.buttonStyle(PrimaryPillStyle()).fixedSize()
            HStack {
                Button("← Précédente") { state.previous() }.buttonStyle(PrimaryPillStyle()).fixedSize()
                Spacer()
                Button("Suivante →") { state.next() }.buttonStyle(PrimaryPillStyle()).fixedSize()
            }
        }
    }
}

/// Dispose les éléments sur une ligne et passe à la suivante seulement si la largeur manque.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, width: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
