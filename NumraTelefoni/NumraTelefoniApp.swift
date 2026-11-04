import SwiftUI
import UIKit

@main
struct NumraTelefoniApp: App {
    @StateObject private var store = PhoneStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                .onChange(of: store.busy) { UIApplication.shared.isIdleTimerDisabled = $0 }
        }
    }
}
