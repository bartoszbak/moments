import WidgetKit
import SwiftUI

@main
struct MomentsWidgetBundle: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
    }
}

struct CountdownWidget: Widget {
    let kind = "CountdownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCountdownIntent.self,
            provider: CountdownProvider()
        ) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("See how many days until or since your event.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}
