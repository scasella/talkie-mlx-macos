import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        ZStack {
            CabinetBackground()

            HStack(spacing: 0) {
                if store.showSidebar {
                    SidebarView()
                        .frame(width: 224)

                    BureauDivider()
                }

                VStack(spacing: 0) {
                    SessionBar()
                    MessageTranscriptView()
                    ComposerView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if store.showInspector {
                    BureauDivider()

                    InspectorView()
                        .frame(width: 300)
                }
            }
        }
        .foregroundStyle(.primary)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.showSidebar.toggle()
                    }
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                }
                .help("Toggle intake tray")

                Button {
                    store.requestClearConversation()
                } label: {
                    Label("New Conversation", systemImage: "square.and.pencil")
                }
                .help("Start a fresh transcript")
            }

            ToolbarItemGroup {
                Button {
                    store.showPayloadPreview.toggle()
                } label: {
                    Label("Payload Preview", systemImage: "doc.plaintext")
                }
                .help("Show the payload preview")

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.showInspector.toggle()
                    }
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle signal inspector")
            }
        }
    }
}

private struct CabinetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                CabinetPalette.soot,
                CabinetPalette.ink,
                Color(red: 0.026, green: 0.026, blue: 0.024)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    CabinetPalette.brass.opacity(0.10),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 680, height: 420)
            .blur(radius: 80)
        }
        .ignoresSafeArea()
    }
}

private struct BureauDivider: View {
    var body: some View {
        Rectangle()
            .fill(CabinetPalette.nickel.opacity(0.18))
            .frame(width: 1)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(.black.opacity(0.22))
                    .frame(width: 1)
                    .offset(x: -1)
            }
    }
}

private struct SessionBar: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Talkie Cabinet")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(CabinetPalette.paperLight)
                        .lineLimit(1)

                    Text(store.branchLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CabinetPalette.brass)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background {
                            Capsule()
                                .fill(CabinetPalette.brass.opacity(0.12))
                                .stroke(CabinetPalette.brass.opacity(0.20), lineWidth: 1)
                        }
                }

                Text("Local MLX q4-safe • pre-1931 instruction model")
                    .font(.caption)
                    .foregroundStyle(CabinetPalette.paperDeep)
                    .lineLimit(1)
            }
            .frame(minWidth: 152, alignment: .leading)

            Spacer()

            Picker("Mode", selection: $store.conversationMode) {
                ForEach(ConversationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 204)

            RuntimeBadge(state: store.runtimeState)
                .frame(width: 154, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.black.opacity(0.15))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(CabinetPalette.nickel.opacity(0.16))
                        .frame(height: 1)
                }
        }
    }
}

private struct RuntimeBadge: View {
    let state: RuntimeState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.65), radius: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(state.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CabinetPalette.paperLight)
                Text(state.detail)
                    .font(.caption2)
                    .foregroundStyle(CabinetPalette.paperDeep)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(CabinetPalette.graphite.opacity(0.66))
                .stroke(CabinetPalette.nickel.opacity(0.20), lineWidth: 1)
        }
    }

    private var color: Color {
        switch state {
        case .ready: CabinetPalette.signal
        case .generating: CabinetPalette.lamp
        case .loading: CabinetPalette.brass
        case .failed: .red
        case .idle: .secondary
        }
    }
}
