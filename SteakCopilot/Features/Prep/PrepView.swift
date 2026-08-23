import SwiftUI

struct PrepView: View {
    @Environment(AppTheme.self) private var theme
    let controller: CookingSessionController
    @State private var dried = false
    @State private var salted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Let's prep your steak")
                    .font(.title2.bold())
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                PrepPhotoStep(
                    imageName: "PrepDry",
                    systemImage: "drop",
                    step: String(localized: "1. DRY"),
                    detail: String(localized: "Pat both sides until very dry."),
                    isComplete: dried
                ) { dried.toggle() }
                .accessibilityIdentifier("prep.dry")

                PrepPhotoStep(
                    imageName: "PrepSalt",
                    systemImage: "saltshaker",
                    step: String(localized: "2. SALT"),
                    detail: String(localized: "Season both sides generously."),
                    isComplete: salted
                ) { salted.toggle() }
                .accessibilityIdentifier("prep.salt")

                PrototypeCard(padding: 14) {
                    HStack(alignment: .top, spacing: 13) {
                        Image(systemName: "snowflake")
                            .font(.title2)
                            .foregroundStyle(theme.butter)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Optional: Dry brine")
                                .font(.subheadline.weight(.semibold))
                            Text("For best results, season and refrigerate uncovered for at least 45 minutes.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }

                PrimaryActionButton(
                    title: String(localized: "I'm ready"),
                    isEnabled: dried && salted
                ) {
                    controller.finishPrep()
                }
                .accessibilityIdentifier("prep.continue")
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PrepPhotoStep: View {
    @Environment(AppTheme.self) private var theme
    let imageName: String
    let systemImage: String
    let step: String
    let detail: String
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 168, height: 148)
                    .clipped()

                VStack(alignment: .leading, spacing: 9) {
                    Image(systemName: systemImage)
                        .font(.title3)
                    Text(step)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isComplete ? theme.ember : .secondary)
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            }
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(
                        isComplete ? theme.ember.opacity(0.55) : .black.opacity(0.045),
                        lineWidth: isComplete ? 1.5 : 1
                    )
            }
            .shadow(color: .black.opacity(0.055), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isComplete ? .isSelected : [])
    }
}
