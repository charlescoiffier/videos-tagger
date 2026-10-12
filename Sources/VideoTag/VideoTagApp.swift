import SwiftUI

@main
struct VideoTagApp: App {
    @State private var state = AppState()

    init() {
        // Infobulles plus rapides (150 ms au lieu d'environ 1,5 s).
        UserDefaults.standard.set(150, forKey: "NSInitialToolTipDelay")
    }

    var body: some Scene {
        WindowGroup("Video Tag") {
            ContentView(state: state)
                .frame(minWidth: 1100, minHeight: 560)
        }
        .defaultSize(width: 1320, height: 760)
    }
}
