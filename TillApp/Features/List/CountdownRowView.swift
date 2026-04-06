import SwiftUI

struct CountdownRowView: View {
    let countdown: Countdown
    let currentTime: Date

    private var daysRemaining: Int {
        Int(countdown.timeRemaining(from: currentTime)) / 86400
    }

    private var isExpired: Bool { countdown.isExpired(at: currentTime) }
    private var isToday: Bool { !isExpired && daysRemaining == 0 }

    var body: some View {
        HStack(spacing: 16) {
            dayBadge
                .frame(width: 52, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(countdown.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(countdown.targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Day Badge

    @ViewBuilder
    private var dayBadge: some View {
        if isExpired {
            Text("Done")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        } else if isToday {
            Text("Today")
                .font(.caption.bold())
                .foregroundStyle(.orange)
        } else {
            VStack(spacing: 0) {
                Text("\(daysRemaining)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: daysRemaining)
                Text("days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        if isExpired { return "\(countdown.title), completed" }
        if isToday { return "\(countdown.title), today" }
        return "\(countdown.title), \(daysRemaining) days remaining"
    }
}
