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
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(donenessColor(doneness))
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
                                Text(doneness.title)
                                    .font(.caption.weight(.semibold))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 70)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(configuration.doneness == doneness ? .white.opacity(0.76) : .clear)
                            )
                        }
                        .buttonStyle(.plain)
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

    private func donenessColor(_ doneness: Doneness) -> Color {
        switch doneness {
        case .rare: Color(red: 0.72, green: 0.08, blue: 0.10)
        case .mediumRare: Color(red: 0.80, green: 0.24, blue: 0.20)
        case .medium: Color(red: 0.67, green: 0.36, blue: 0.28)
        }
    }
}
