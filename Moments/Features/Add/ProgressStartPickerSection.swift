import SwiftUI

struct ProgressStartPickerSection: View {
    @Binding var value: Double

    var body: some View {
        Section {
            Slider(value: $value, in: 0.5...1.0, step: 0.125) {
                Text("Progress Indicator")
            } minimumValueLabel: {
                Text("50%").font(.caption)
            } maximumValueLabel: {
                Text("100%").font(.caption)
            }
        } header: {
            Text("Progress Indicator")
        } footer: {
            Text("The bar starts at \(Int(value * 100))% on the widget and shrinks to zero on your event date.")
        }
    }
}
