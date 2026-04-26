import WidgetKit
import SwiftUI

@main
struct MomentsWidgetBundle: WidgetBundle {
    init() {
        ManifestationTypography.configure()
    }

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
        .configurationDisplayName("Widget")
        .description("See how many days until or since your moment.")
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}
