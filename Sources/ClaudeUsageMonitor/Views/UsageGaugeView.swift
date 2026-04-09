import SwiftUI

struct UsageGaugeView: View {
    let percentage: Double
    let resetDate: Date?

    var body: some View {
        VStack(spacing: DS.Space._3) {
            // Ring with only % inside
            ZStack {
                Circle()
                    .stroke(DS.Color.border, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(
                        DS.Color.usage(percentage),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: percentage)

                Text("\(Int(percentage))%")
                    .font(DS.Font.gauge)
            }
            .frame(width: 120, height: 120)

            // Reset time below the ring — clean and readable
            if let reset = resetDate {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text("Resets in \(DateFormatting.countdown(to: reset, from: context.date))")
                        .font(DS.Font.gaugeSub)
                        .foregroundStyle(DS.Color.secondary)
                }
            }
        }
    }
}
