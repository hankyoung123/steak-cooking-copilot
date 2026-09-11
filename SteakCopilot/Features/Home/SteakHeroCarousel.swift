import SwiftUI

/// The setup screen's hero artwork carousel.
///
/// The card geometry comes from the resolved `HomeLayoutMetrics` — the card
/// width, the artwork inset and the rendered artwork side are all decided once
/// per device, so swiping between cuts swaps the picture inside a fixed frame
/// and never resizes the card.
///
/// The optical correction shifts the artwork by a fraction of its own rendered
/// side (see `SteakCut.heroOpticalOffset`), so it stays correct at every device
/// size instead of being a fixed number of points.
struct SteakHeroCarousel: View {
    @Binding var selection: SteakCut
    let layout: HomeLayoutMetrics

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: AppSpacing.sm) {
                ForEach(SteakCut.allCases) { cut in
                    Button {
                        selection = cut
                    } label: {
                        card(for: cut)
                    }
                    .buttonStyle(.plain)
                    .id(cut)
                    .accessibilityLabel(cut.title)
                    .accessibilityIdentifier("setup.cut.\(cut.rawValue)")
                    .accessibilityAddTraits(selection == cut ? .isSelected : [])
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        // Only a gentle depth cue while dragging. The card itself
                        // stays put once settled, so the composition does not
                        // appear to move on selection.
                        content
                            .scaleEffect(1 - abs(phase.value) * 0.06)
                            .opacity(1 - abs(phase.value) * 0.4)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, HomeLayoutMetrics.carouselContentMargin, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: Binding(
            get: { selection },
            set: { newValue in
                if let newValue { selection = newValue }
            }
        ))
        .sensoryFeedback(.selection, trigger: selection)
        .animation(.smooth(duration: 0.42), value: selection)
    }

    private func card(for cut: SteakCut) -> some View {
        let side = layout.heroImageSide
        return Image(cut.heroAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .offset(x: side * cut.heroOpticalOffset)
            .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 12)
            .frame(width: layout.heroFrameWidth, height: layout.heroHeight)
            .contentTransition(.opacity)
    }
}
