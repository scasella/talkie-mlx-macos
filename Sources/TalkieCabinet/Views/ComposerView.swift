import SwiftUI

struct ComposerView: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ComposerTopRow()

            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $store.draft)
                        .font(.system(size: 15.5, design: .serif))
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(CabinetPalette.paperLight)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .frame(minHeight: 72, maxHeight: 112)
                        .onKeyPress(.return, phases: .down) { press in
                            if press.modifiers.contains(.command) {
                                Task { await store.sendDraft() }
                                return .handled
                            }
                            return .ignored
                        }

                    if store.draft.isEmpty {
                        Text("Ask from the cabinet...")
                            .font(.system(size: 15.5, design: .serif))
                            .foregroundStyle(CabinetPalette.paperDeep.opacity(0.64))
                            .padding(.horizontal, 17)
                            .padding(.vertical, 17)
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(CabinetPalette.soot.opacity(0.70))
                        .stroke(CabinetPalette.nickel.opacity(0.22), lineWidth: 1)
                }

                VStack(spacing: 8) {
                    if store.isGenerating {
                        Button {
                            store.stopGeneration()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 34, height: 30)
                        }
                        .buttonStyle(CompactTransmitButtonStyle(kind: .stop))
                        .help("Stop generation")
                    } else {
                        Button {
                            Task { await store.sendDraft() }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 34, height: 30)
                        }
                        .buttonStyle(CompactTransmitButtonStyle(kind: .send))
                        .disabled(!store.canSend)
                        .help("Send with Command-Return")
                    }

                    Button {
                        Task { await store.retryLast() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 34, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(CabinetPalette.paperDeep)
                    .disabled(store.isGenerating || store.messages.last(where: { $0.role == .user }) == nil)
                    .help("Retry last user turn")
                }
            }

            HStack(spacing: 10) {
                Text(store.runtimeState.detail)
                    .foregroundStyle(CabinetPalette.paperDeep)
                    .lineLimit(1)

                Spacer()

                if !store.workerLog.isEmpty {
                    Text(store.workerLog)
                        .foregroundStyle(CabinetPalette.paperDeep.opacity(0.7))
                        .lineLimit(1)
                }

                Text("⌘↩ Send")
                    .foregroundStyle(CabinetPalette.nickel)
            }
            .font(.caption)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background {
            Rectangle()
                .fill(.black.opacity(0.20))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(CabinetPalette.nickel.opacity(0.14))
                        .frame(height: 1)
                }
        }
    }
}

private struct ComposerTopRow: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        HStack(spacing: 10) {
            if store.activePromptStack.isEmpty {
                Text("No prompt slip")
                    .font(.caption)
                    .foregroundStyle(CabinetPalette.paperDeep)
            } else {
                ForEach(store.activePromptStack) { preset in
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text")
                        Text(preset.title)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CabinetPalette.inkOnPaper)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(CabinetPalette.paperLight)
                    }
                }
            }

            Spacer()

            Picker("Context", selection: $store.contextMode) {
                ForEach(ContextMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 86)
            .help("Choose what context will be sent")

            ContextMeter()
        }
    }
}

private struct ContextMeter: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        HStack(spacing: 7) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CabinetPalette.nickel.opacity(0.20))
                    Capsule()
                        .fill(meterColor)
                        .frame(width: max(6, geometry.size.width * store.contextFill))
                }
            }
            .frame(width: 88, height: 5)

            Text("~\(store.contextEstimate)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(CabinetPalette.paperDeep)
        }
        .help("Estimated context tokens for the next turn")
    }

    private var meterColor: Color {
        if store.contextFill > 0.85 { return .red.opacity(0.72) }
        if store.contextFill > 0.60 { return CabinetPalette.lamp }
        return CabinetPalette.signal.opacity(0.82)
    }
}

private enum TransmitButtonKind {
    case send
    case stop
}

private struct CompactTransmitButtonStyle: ButtonStyle {
    let kind: TransmitButtonKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(kind == .send ? CabinetPalette.inkOnPaper : CabinetPalette.paperLight)
            .background {
                RoundedRectangle(cornerRadius: 9)
                    .fill(background(configuration: configuration))
                    .stroke(CabinetPalette.brass.opacity(0.20), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }

    private func background(configuration: Configuration) -> Color {
        switch kind {
        case .send:
            return CabinetPalette.lamp.opacity(configuration.isPressed ? 0.70 : 0.96)
        case .stop:
            return CabinetPalette.oxblood.opacity(configuration.isPressed ? 0.62 : 0.86)
        }
    }
}
