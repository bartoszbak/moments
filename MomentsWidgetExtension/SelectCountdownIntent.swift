import AppIntents
import WidgetKit

struct SelectCountdownIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Moment"
    static var description = IntentDescription("Choose which moment to display.")

    @Parameter(title: "Moment")
    var countdown: CountdownAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Select \(\.$countdown)")
    }
}
