import SwiftUI

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView()
            Text(message)
                .font(AppFont.germanCaption())
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when a real failure occurred (e.g. content hash mismatch) — never silently hidden,
/// per CLAUDE.md's "keine Dummy-Erfolge".
struct ErrorStateView: View {
    let title: String
    let detail: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.largeTitle)
            Text(title)
                .font(AppFont.sectionHeader())
            Text(detail)
                .font(AppFont.germanCaption())
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                SecondaryButton(title: "Erneut versuchen", action: retry)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
