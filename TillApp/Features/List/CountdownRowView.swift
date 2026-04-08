import SwiftUI

struct CountdownRowView: View {
    let countdown: Countdown
    let currentTime: Date

    private var isExpired: Bool { countdown.isExpired(at: currentTime) }
    private var isToday: Bool { countdown.isToday(at: currentTime) }
    private var daysUntil: Int { countdown.daysUntil(from: currentTime) }
    private var daysSince: Int { countdown.daysSince(from: currentTime) }

    var body: some View {
        HStack(spacing: 16) {
            dayBadge
                .frame(width: 52, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(countdown.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(countdown.targetDate.smartFormatted)
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
        if isToday {
            Text("Today")
                .font(.caption.bold())
                .foregroundStyle(.orange)
        } else if isExpired {
            VStack(spacing: 0) {
                Text("\(daysSince)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.default, value: daysSince)
                Text("since")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 0) {
                Text("\(daysUntil)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: daysUntil)
                Text("days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        if isToday { return "\(countdown.title), today" }
        if isExpired { return "\(countdown.title), \(daysSince) days since" }
        return "\(countdown.title), \(daysUntil) days until"
    }
}
