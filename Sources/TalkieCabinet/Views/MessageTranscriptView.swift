import SwiftUI

struct MessageTranscriptView: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        VStack(spacing: 0) {
            TranscriptControlBar()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if store.showPayloadPreview {
                            PayloadPreviewCard()
                                .padding(.horizontal, 28)
                                .padding(.top, 22)
                                .padding(.bottom, 10)
                        }

                        ForEach(Array(store.messages.enumerated()), id: \.element.id) { index, message in
                            MessageLedgerRow(message: message, turnNumber: index + 1)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background {
                    TranscriptPaper()
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 22)
                .padding(.bottom, 10)
                .onChange(of: store.messages) { _, messages in
                    guard let last = messages.last else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(.black.opacity(0.08))
    }
}

private struct TranscriptControlBar: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        HStack(spacing: 10) {
            Label("Transcript Platen", systemImage: "doc.text")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CabinetPalette.paperDeep)

            Text("\(store.messages.count) turns")
                .font(.caption.monospacedDigit())
                .foregroundStyle(CabinetPalette.nickel)

            Spacer()

            CompactTranscriptButton("Branch", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
                if let message = store.messages.last {
                    store.startBranch(from: message)
                }
            }

            CompactTranscriptButton("Payload", systemImage: "doc.plaintext") {
                store.showPayloadPreview.toggle()
            }

            CompactTranscriptButton("Copy", systemImage: "doc.on.doc") {
                store.copyPayloadPreview()
            }

            CompactTranscriptButton("Clear", systemImage: "xmark.circle") {
                store.requestClearConversation()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
        .background {
            Rectangle()
                .fill(.black.opacity(0.10))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(CabinetPalette.nickel.opacity(0.12))
                        .frame(height: 1)
                }
        }
    }
}

private struct CompactTranscriptButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(CabinetPalette.paperDeep)
        .help(title)
    }
}

private struct TranscriptPaper: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(
                LinearGradient(
                    colors: [
                        CabinetPalette.paperLight.opacity(0.96),
                        CabinetPalette.paper.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(CabinetPalette.oxblood.opacity(0.30))
                    .frame(width: 3)
                    .padding(.vertical, 18)
                    .padding(.leading, 22)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(CabinetPalette.nickel.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 24, y: 16)
    }
}

private struct PayloadPreviewCard: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Payload Preview", systemImage: "curlybraces")
                    .font(.caption.weight(.bold))
                Spacer()
                Button("Copy") {
                    store.copyPayloadPreview()
                }
                .buttonStyle(.borderless)
            }
            .foregroundStyle(CabinetPalette.inkOnPaper)

            Text(store.payloadPreview)
                .font(.system(size: 11.5, design: .monospaced))
                .lineSpacing(3)
                .foregroundStyle(CabinetPalette.inkOnPaper.opacity(0.84))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(CabinetPalette.paper.opacity(0.86))
                .stroke(CabinetPalette.oxblood.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct MessageLedgerRow: View {
    @EnvironmentObject private var store: ChatStore
    let message: ChatMessage
    let turnNumber: Int

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .trailing, spacing: 5) {
                Text(String(format: "%02d", turnNumber))
                    .font(.system(size: 11, design: .monospaced).weight(.semibold))
                    .foregroundStyle(CabinetPalette.oxblood.opacity(0.72))
                Text(message.role == .assistant ? "RX" : "TX")
                    .font(.system(size: 10, design: .monospaced).weight(.bold))
                    .foregroundStyle(message.role == .assistant ? CabinetPalette.mutedGreen : CabinetPalette.brass)
                if store.pinnedMessageIDs.contains(message.id) {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(CabinetPalette.oxblood)
                }
            }
            .frame(width: 42)
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(message.role.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CabinetPalette.inkOnPaper)
                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(CabinetPalette.inkOnPaper.opacity(0.52))

                    Spacer()

                    if isHovering || store.selectedMessageID == message.id {
                        MessageActionStrip(message: message)
                    }
                }

                Text(message.text.isEmpty ? "…" : message.text)
                    .font(.system(size: message.role == .assistant ? 16.2 : 15.2, weight: .regular, design: .serif))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .foregroundStyle(CabinetPalette.inkOnPaper)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 760, alignment: .leading)
            }
            .padding(.horizontal, message.role == .assistant ? 0 : 12)
            .padding(.vertical, 15)
            .background {
                if message.role == .user {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.055))
                        .stroke(CabinetPalette.brass.opacity(0.18), lineWidth: 1)
                }
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 28)
        .background {
            Rectangle()
                .fill(store.selectedMessageID == message.id ? CabinetPalette.brass.opacity(0.09) : .clear)
        }
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(CabinetPalette.inkOnPaper.opacity(0.10))
                .frame(height: 1)
                .padding(.leading, 86)
                .padding(.trailing, 28)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectedMessageID = message.id
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy") {
                store.copyMessage(message)
            }
            Button(store.pinnedMessageIDs.contains(message.id) ? "Unpin" : "Pin") {
                store.togglePin(message)
            }
            Button("Retry from Here") {
                Task { await store.retry(from: message) }
            }
            Button("Branch from Here") {
                store.startBranch(from: message)
            }
            Divider()
            Button("Delete", role: .destructive) {
                store.requestRemoveMessage(message)
            }
        }
    }
}

private struct MessageActionStrip: View {
    @EnvironmentObject private var store: ChatStore
    let message: ChatMessage

    var body: some View {
        HStack(spacing: 5) {
            IconAction("Copy", systemImage: "doc.on.doc") {
                store.copyMessage(message)
            }
            IconAction(store.pinnedMessageIDs.contains(message.id) ? "Unpin" : "Pin", systemImage: store.pinnedMessageIDs.contains(message.id) ? "pin.slash" : "pin") {
                store.togglePin(message)
            }
            IconAction("Retry", systemImage: "arrow.clockwise") {
                Task { await store.retry(from: message) }
            }
            IconAction("Branch", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
                store.startBranch(from: message)
            }
        }
    }
}

private struct IconAction: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption)
                .frame(width: 22, height: 20)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(CabinetPalette.inkOnPaper.opacity(0.66))
        .help(title)
    }
}
