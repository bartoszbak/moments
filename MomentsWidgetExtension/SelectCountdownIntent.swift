import AppIntents
import WidgetKit

struct SelectCountdownIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Countdown"
    static var description = IntentDescription("Choose which countdown to display.")

    @Parameter(title: "Countdown")
    var countdown: CountdownAppEntity?
}
