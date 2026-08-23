import SwiftUI

struct FeedbackView: View {
    let controller: CookingSessionController
    @State private var doneness: DonenessFeedback = .perfect
    @State private var crust: CrustFeedback = .perfect

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("ONE LAST THING")
                        .quietEyebrowStyle(color: .primary)
                    Text("Help the next steak.")
                        .font(.largeTitle.bold())
                }
                .padding(.top, 26)

                SteakVisual(
                    configuration: controller.session.configuration,
                    cookedProgress: 1,
                    sliced: true
                )
                .frame(height: 170)
                .padding(.horizontal, 22)

                feedbackSection(title: String(localized: "DONENESS")) {
                    ForEach(DonenessFeedback.allCases) { option in
                        feedbackButton(
                            title: option.title,
                            isSelected: doneness == option
                        ) { doneness = option }
                    }
                }

                feedbackSection(title: String(localized: "CRUST")) {
                    ForEach(CrustFeedback.allCases) { option in
                        feedbackButton(
                            title: option.title,
                            isSelected: crust == option
                        ) { crust = option }
                    }
                }

                PrimaryActionButton(
                    title: String(localized: "Save feedback"),
                    icon: "checkmark"
                ) {
                    controller.submitFeedback(doneness: doneness, crust: crust)
                }
                .accessibilityIdentifier("feedback.save")
                .padding(.top, 8)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func feedbackSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .quietEyebrowStyle(color: .primary)
            VStack(spacing: 8) { content() }
        }
    }

    private func feedbackButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? .white.opacity(0.8) : .white.opacity(0.34))
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
