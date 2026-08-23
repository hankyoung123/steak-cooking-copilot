import SwiftUI

struct FeedbackView: View {
    @Environment(AppTheme.self) private var theme
    let controller: CookingSessionController
    @State private var doneness: DonenessFeedback = .perfect
    @State private var crust: CrustFeedback = .perfect

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 5) {
                    Text("How was it?")
                        .font(.title2.bold())
                    Text("This helps improve next time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 10) {
                    PrototypeSectionLabel(title: String(localized: "Doneness"))
                    HStack(alignment: .top, spacing: 5) {
                        ForEach(DonenessFeedback.allCases) { option in
                            donenessButton(option)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    PrototypeSectionLabel(title: String(localized: "Crust"))
                    HStack(alignment: .top, spacing: 9) {
                        ForEach(CrustFeedback.allCases) { option in
                            crustButton(option)
                        }
                    }
                }

                PrototypeCard(padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(theme.ember)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(controller.session.configuration.cut.title)
                                .font(.subheadline.weight(.semibold))
                            Text(sessionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.ember)
                    }
                }

                PrimaryActionButton(title: String(localized: "Save")) {
                    controller.submitFeedback(doneness: doneness, crust: crust)
                }
                .accessibilityIdentifier("feedback.save")
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func donenessButton(_ option: DonenessFeedback) -> some View {
        Button {
            doneness = option
        } label: {
            VStack(spacing: 6) {
                Image(donenessAssetName(for: option))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)
                Text(option.title)
                    .font(.system(.caption2, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .top)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(
                        doneness == option ? theme.ember : .black.opacity(0.045),
                        lineWidth: doneness == option ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(doneness == option ? .isSelected : [])
    }

    private func crustButton(_ option: CrustFeedback) -> some View {
        Button {
            crust = option
        } label: {
            VStack(spacing: 7) {
                Image("SteakSurface")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .brightness(crustBrightness(for: option))
                Text(option.title)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
            .padding(5)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .top)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        crust == option ? theme.ember : .black.opacity(0.045),
                        lineWidth: crust == option ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(crust == option ? .isSelected : [])
    }

    private func donenessAssetName(for option: DonenessFeedback) -> String {
        switch option {
        case .tooRare: Doneness.rare.assetName
        case .slightlyRare: Doneness.mediumRare.assetName
        case .perfect: Doneness.medium.assetName
        case .slightlyDone: Doneness.mediumWell.assetName
        case .tooDone: Doneness.wellDone.assetName
        }
    }

    private func crustBrightness(for option: CrustFeedback) -> Double {
        switch option {
        case .tooLight: 0.16
        case .perfect: 0
        case .tooDark: -0.2
        }
    }

    private var sessionSummary: String {
        String(
            format: String(localized: "%.1f cm · %@"),
            controller.session.configuration.thicknessCM,
            controller.session.configuration.doneness.title
        )
    }
}
