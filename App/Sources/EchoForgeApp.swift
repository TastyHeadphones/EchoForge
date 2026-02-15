import SwiftUI
import EchoForgeFeatures

@main
struct EchoForgeApp: App {
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            RootView()
                .frame(minWidth: 900, minHeight: 650)
            #else
            RootView()
            #endif
        }
    }
}
