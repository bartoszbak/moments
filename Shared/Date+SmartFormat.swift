import Foundation

extension Date {
    /// "Aug 12" when same year as today, "Aug 12, 2027" when different year.
    var smartFormatted: String {
        let sameYear = Calendar.current.component(.year, from: self) == Calendar.current.component(.year, from: Date())
        let style: Date.FormatStyle = sameYear
            ? .dateTime.month(.abbreviated).day()
            : .dateTime.month(.abbreviated).day().year()
        return self.formatted(style)
    }
}
