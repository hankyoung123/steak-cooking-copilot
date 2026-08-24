import SwiftUI

struct SteakHeroCarousel: View {
    @Binding var selection: SteakCut

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: AppSpacing.sm) {
                    ForEach(SteakCut.allCases) { cut in
                        Button {
                            selection = cut
                        } label: {
                            Image(cut.heroAssetName)
                                .resizable()
                                .scaledToFit()
                                .padding(20)
                                .frame(width: max(268, proxy.size.width - 86))
                                .shadow(color: .black.opacity(0.2), radius: 18, x: 4, y: 14)
                        }
                        .buttonStyle(.plain)
                        .id(cut)
                        .accessibilityLabel(cut.title)
                        .accessibilityIdentifier("setup.cut.\(cut.rawValue)")
                        .accessibilityAddTraits(selection == cut ? .isSelected : [])
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(1 - abs(phase.value) * 0.09)
                                .opacity(1 - abs(phase.value) * 0.52)
                                .rotationEffect(.degrees(phase.value * 2.4))
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 43, for: .scrollContent)
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
    }
}
