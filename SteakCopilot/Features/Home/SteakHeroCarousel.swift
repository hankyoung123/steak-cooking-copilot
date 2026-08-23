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
                                .padding(.horizontal, AppSpacing.sm)
                                .frame(width: max(250, proxy.size.width - 180))
                                .scaleEffect(selection == cut ? 1 : 0.88)
                                .opacity(selection == cut ? 1 : 0.42)
                        }
                        .buttonStyle(.plain)
                        .id(cut)
                        .accessibilityLabel(cut.title)
                        .accessibilityIdentifier("setup.cut.\(cut.rawValue)")
                        .accessibilityAddTraits(selection == cut ? .isSelected : [])
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 44, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: Binding(
                get: { selection },
                set: { newValue in
                    if let newValue { selection = newValue }
                }
            ))
            .sensoryFeedback(.selection, trigger: selection)
            .animation(.easeOut(duration: 0.42), value: selection)
        }
    }
}
