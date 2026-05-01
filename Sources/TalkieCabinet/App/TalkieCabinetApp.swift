import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct TalkieCabinetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup("Talkie Cabinet") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1040, minHeight: 720)
                .task {
                    await store.bootstrap()
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Send Message") {
                    Task { await store.sendDraft() }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!store.canSend)

                Button("Stop Generation") {
                    store.stopGeneration()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!store.isGenerating)

                Button("Toggle Inspector") {
                    store.showInspector.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Button("Toggle Sidebar") {
                    store.showSidebar.toggle()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])

                Button("Payload Preview") {
                    store.showPayloadPreview.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
            }
        }
    }
}
