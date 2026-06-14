import SwiftUI

struct IntervalRingView<Content: View>: View {
    let progress: Double
    let ringColor: Color
    let accessibilityLabel: String
    var size: CGFloat = 220
    var strokeWidth: CGFloat = 18
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: .systemFill), lineWidth: strokeWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            content()
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
