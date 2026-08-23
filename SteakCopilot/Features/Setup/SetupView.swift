import SwiftUI

struct SetupView: View {
    @Environment(AppTheme.self) private var theme
    let controller: CookingSessionController
    @State private var configuration: SteakConfiguration

    init(controller: CookingSessionController) {
        self.controller = controller
        _configuration = State(initialValue: controller.session.configuration)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                setupHeader

                VStack(spacing: 7) {
                    Text("What are we cooking?")
                        .font(.title2.bold())
                    Text(configuration.cut.title)
                        .font(.headline)
                        .foregroundStyle(theme.ember)
                }

                cutPicker

                Image("RawSteak")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .accessibilityHidden(true)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: configuration.cut)

                thicknessControl
                donenessControl
                cookingMethod

                PrimaryActionButton(title: String(localized: "Start Cooking")) {
                    controller.updateConfiguration(configuration)
                    controller.finishSetup()
                }
                .accessibilityIdentifier("setup.primary")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .onChange(of: configuration) { _, value in
            controller.updateConfiguration(value)
        }
    }

    private var setupHeader: some View {
        HStack {
            Color.clear.frame(width: 40, height: 40)
            Spacer()
            StageTitle(stage: .setup)
            Spacer()
            Menu {
                Picker("Cut", selection: $configuration.cut) {
                    ForEach(SteakCut.allCases) { cut in
                        Text(cut.title).tag(cut)
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Cooking preferences")
        }
        .padding(.top, 8)
    }

    private var cutPicker: some View {
        HStack(spacing: 7) {
            ForEach(SteakCut.allCases) { cut in
                Button {
                    configuration.cut = cut
                } label: {
                    Text(cut.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .foregroundStyle(configuration.cut == cut ? .white : .primary)
                        .background(
                            configuration.cut == cut
                                ? theme.ember
                                : theme.card,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("setup.cut.\(cut.rawValue)")
                .accessibilityAddTraits(configuration.cut == cut ? .isSelected : [])
            }
        }
    }

    private var thicknessControl: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text("Thickness")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(thicknessText)
                    .font(.title3.bold().monospacedDigit())
            }

            HStack(spacing: 12) {
                thicknessButton(systemImage: "minus") {
                    configuration.thicknessCM = max(2, configuration.thicknessCM - 0.5)
                }
                Slider(value: $configuration.thicknessCM, in: 2...5, step: 0.5)
                    .tint(theme.ember)
                    .accessibilityLabel("Steak thickness")
                    .accessibilityIdentifier("setup.thickness")
                thicknessButton(systemImage: "plus") {
                    configuration.thicknessCM = min(5, configuration.thicknessCM + 0.5)
                }
            }
        }
    }

    private func thicknessButton(
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
    }

    private var donenessControl: some View {
        VStack(spacing: 9) {
            PrototypeSectionLabel(title: String(localized: "Doneness"))
                .padding(.horizontal, 4)

            HStack(spacing: 5) {
                ForEach(Doneness.allCases) { doneness in
                    Button {
                        configuration.doneness = doneness
                    } label: {
                        VStack(spacing: 6) {
                            Image(doneness.assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 44)
                            Text(doneness.title)
                                .font(.caption2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 82)
                        .padding(4)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: 13))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(
                                    configuration.doneness == doneness
                                        ? theme.ember
                                        : .black.opacity(0.05),
                                    lineWidth: configuration.doneness == doneness ? 1.5 : 1
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

    private var cookingMethod: some View {
        PrototypeCard(padding: 13) {
            HStack(spacing: 12) {
                Image(systemName: "frying.pan")
                    .font(.title3)
                    .foregroundStyle(theme.ember)
                VStack(alignment: .leading, spacing: 2) {
                    Text("How will you cook?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Pan-sear")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thicknessText: String {
        String(
            format: String(localized: "%.1f cm"),
            configuration.thicknessCM
        )
    }
}
