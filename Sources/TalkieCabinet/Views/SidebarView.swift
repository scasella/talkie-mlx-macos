import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BureauSeal()

            SearchField(text: $store.sidebarFilter)

            VStack(alignment: .leading, spacing: 4) {
                SourceRow(title: "Today", icon: "clock", count: store.messages.count, isActive: true)
                SourceRow(title: "Findings", icon: "pin", count: store.pinnedMessageIDs.count, isActive: false)
                SourceRow(title: "Archive", icon: "archivebox", count: 0, isActive: false)
            }

            Divider()
                .overlay(CabinetPalette.nickel.opacity(0.18))

            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt Slips")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CabinetPalette.paperDeep)
                    .textCase(.uppercase)
                    .tracking(0.8)

                ForEach(store.visiblePresets) { preset in
                    Button {
                        store.applyPreset(preset)
                    } label: {
                        PromptSlipRow(preset: preset, isSelected: preset.id == store.selectedPresetID)
                    }
                    .buttonStyle(.plain)
                    .help(preset.prompt)
                }
            }

            Spacer(minLength: 10)

            PromptStackCard()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background {
            Rectangle()
                .fill(.black.opacity(0.20))
                .overlay {
                    CabinetPalette.graphite.opacity(0.32)
                }
        }
    }
}

private struct BureauSeal: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(CabinetPalette.oxblood)
                    .stroke(CabinetPalette.brass.opacity(0.44), lineWidth: 1)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CabinetPalette.lamp)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text("Listening Bureau")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CabinetPalette.paperLight)
                Text("Local cabinet")
                    .font(.caption2)
                    .foregroundStyle(CabinetPalette.paperDeep)
            }

            Spacer()
        }
        .padding(.bottom, 2)
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CabinetPalette.paperDeep)
            TextField("Search slips", text: $text)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(CabinetPalette.paperLight)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.22))
                .stroke(CabinetPalette.nickel.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct SourceRow: View {
    let title: String
    let icon: String
    let count: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 17)
                .foregroundStyle(isActive ? CabinetPalette.lamp : CabinetPalette.paperDeep)
            Text(title)
                .font(.callout)
                .foregroundStyle(isActive ? CabinetPalette.paperLight : CabinetPalette.paperDeep)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(CabinetPalette.paperDeep)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? CabinetPalette.brass.opacity(0.12) : .clear)
        }
    }
}

private struct PromptSlipRow: View {
    let preset: PromptPreset
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            VStack(spacing: 2) {
                Circle()
                    .fill(isSelected ? CabinetPalette.lamp : CabinetPalette.nickel.opacity(0.45))
                    .frame(width: 6, height: 6)
                Rectangle()
                    .fill(CabinetPalette.nickel.opacity(0.28))
                    .frame(width: 1, height: 28)
            }
            .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(preset.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(CabinetPalette.paperLight)
                    Spacer(minLength: 4)
                    Text("~\(max(8, preset.prompt.count / 4))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(CabinetPalette.brass)
                }

                Text(preset.subtitle)
                    .font(.caption)
                    .foregroundStyle(CabinetPalette.paperDeep)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 9)
                .fill(isSelected ? CabinetPalette.paper.opacity(0.10) : .white.opacity(0.035))
                .stroke(isSelected ? CabinetPalette.brass.opacity(0.38) : CabinetPalette.nickel.opacity(0.11), lineWidth: 1)
        }
    }
}

private struct PromptStackCard: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Prompt Stack", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CabinetPalette.paperDeep)
                Spacer()
                Text("\(store.contextEstimate)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(CabinetPalette.lamp)
            }

            if store.activePromptStack.isEmpty {
                Text("No slip attached. Choose one above to prefill the next turn.")
                    .font(.caption)
                    .foregroundStyle(CabinetPalette.paperDeep)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(store.activePromptStack) { preset in
                    Text(preset.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CabinetPalette.inkOnPaper)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(CabinetPalette.paperLight)
                        }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(CabinetPalette.inkRaised.opacity(0.74))
                .stroke(CabinetPalette.nickel.opacity(0.18), lineWidth: 1)
        }
    }
}
