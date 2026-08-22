import SwiftUI

struct SetupView: View {
    let controller: CookingSessionController
    @State private var configuration: SteakConfiguration
    @Namespace private var cutSelection

    init(controller: CookingSessionController) {
        self.controller = controller
        _configuration = State(initialValue: controller.session.configuration)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    Text("PERFECT STEAK")
                        .quietEyebrowStyle(color: .primary)
                    Text("Start with the steak\nin front of you.")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 18)

                SteakVisual(configuration: configuration)
                    .frame(height: 180 + configuration.thicknessCM * 12)
                    .padding(.horizontal, 34)
                    .contentTransition(.opacity)
                    .animation(.spring(duration: 0.38, bounce: 0.12), value: configuration)

                configurationControls

                PrimaryActionButton(title: "Prepare this steak", icon: "arrow.right") {
                    controller.updateConfiguration(configuration)
                    controller.finishSetup()
                }
                .accessibilityIdentifier("setup.primary")
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .onChange(of: configuration) { _, value in
            controller.updateConfiguration(value)
        }
    }

    private var configurationControls: some View {
        VStack(spacing: 22) {
            controlSection(title: "CUT") {
                HStack(spacing: 8) {
                    ForEach(SteakCut.allCases) { cut in
                        Button {
                            configuration.cut = cut
                        } label: {
                            Text(cut.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background {
                                    if configuration.cut == cut {
                                        Capsule()
                                            .fill(.black.opacity(0.9))
                                            .matchedGeometryEffect(id: "cut", in: cutSelection)
                                    }
                                }
                                .foregroundStyle(configuration.cut == cut ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("setup.cut.\(cut.rawValue)")
                        .accessibilityAddTraits(configuration.cut == cut ? .isSelected : [])
                    }
                }
                .padding(4)
                .background(.black.opacity(0.055), in: Capsule())
            }

            controlSection(title: "THICKNESS") {
                HStack(spacing: 16) {
                    Slider(value: $configuration.thicknessCM, in: 2...5, step: 0.5)
                        .tint(.brown)
                        .accessibilityLabel("Steak thickness")
                        .accessibilityIdentifier("setup.thickness")
                    Text("\(configuration.thicknessCM, specifier: "%.1f") cm")
                        .font(.headline.monospacedDigit())
                        .frame(width: 70, alignment: .trailing)
                }
            }

            controlSection(title: "DONENESS") {
                HStack(spacing: 8) {
                    ForEach(Doneness.allCases) { doneness in
                        Button {
                            configuration.doneness = doneness
                        } label: {
                            VStack(spacing: 7) {
                                Image(donenessAssetName(for: doneness))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                Text(doneness.title)
                                    .font(.caption.weight(.semibold))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 108)
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(
                                        configuration.doneness == doneness
                                            ? .white.opacity(0.9)
                                            : .white.opacity(0.24)
                                    )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        configuration.doneness == doneness
                                            ? .black.opacity(0.82)
                                            : .clear,
                                        lineWidth: 2
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("setup.doneness.\(doneness.rawValue)")
                        .accessibilityAddTraits(configuration.doneness == doneness ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func controlSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .quietEyebrowStyle(color: .primary)
            content()
        }
    }

    private func donenessAssetName(for doneness: Doneness) -> String {
        switch doneness {
        case .rare: "DonenessRare"
        case .mediumRare: "DonenessMediumRare"
        case .medium: "DonenessMedium"
        }
    }
}
