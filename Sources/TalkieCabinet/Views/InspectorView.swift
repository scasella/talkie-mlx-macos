import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var runExpanded = true
    @State private var tuningExpanded = false
    @State private var contextExpanded = true
    @State private var findingExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Signal Inspector")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(CabinetPalette.paperLight)
                Spacer()
                Button {
                    store.showInspector = false
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(CabinetPalette.paperDeep)
                .help("Hide inspector")
            }

            InspectorSection("Run", systemImage: "waveform.path.ecg", isExpanded: $runExpanded) {
                RuntimeRows()
            }

            InspectorSection("Tuning", systemImage: "slider.horizontal.3", isExpanded: $tuningExpanded) {
                ControlPanel(settings: $store.settings)
            }

            InspectorSection("Context", systemImage: "rectangle.stack", isExpanded: $contextExpanded) {
                ContextPanel()
            }

            InspectorSection("Finding", systemImage: "pin", isExpanded: $findingExpanded) {
                FindingPanel()
            }

            Spacer()
        }
        .padding(16)
        .background {
            Rectangle()
                .fill(.black.opacity(0.21))
                .overlay(CabinetPalette.graphite.opacity(0.20))
        }
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    let systemImage: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    init(_ title: String, systemImage: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
                .padding(.top, 9)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                    .foregroundStyle(CabinetPalette.brass)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CabinetPalette.paperDeep)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(CabinetPalette.soot.opacity(0.38))
                .stroke(CabinetPalette.nickel.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct RuntimeRows: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        VStack(spacing: 8) {
            MetricRow(label: "Status", value: store.runtimeState.title)
            MetricRow(label: "Decode", value: "\(store.metrics.generationTokensPerSecond.oneDecimal) tok/s")
            MetricRow(label: "Prompt", value: "\(store.metrics.promptTokensPerSecond.oneDecimal) tok/s")
            MetricRow(label: "Peak", value: "\(store.metrics.peakMemoryGB.twoDecimals) GB")
            MetricRow(label: "Load", value: store.metrics.loadSeconds > 0 ? "\(store.metrics.loadSeconds.oneDecimal)s" : "—")
            MetricRow(label: "Branch", value: store.branchLabel)
        }
    }
}

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(CabinetPalette.paperDeep)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(CabinetPalette.paperLight)
                .lineLimit(1)
        }
        .font(.caption)
    }
}

private struct ControlPanel: View {
    @Binding var settings: GenerationSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 7) {
                ControlLabel("Temperature", value: settings.temperature.twoDecimals)
                Slider(value: $settings.temperature, in: 0...1.4, step: 0.05)
            }

            VStack(alignment: .leading, spacing: 7) {
                ControlLabel("Top-p", value: settings.topP.twoDecimals)
                Slider(value: $settings.topP, in: 0.1...1.0, step: 0.05)
            }

            HStack {
                ControlLabel("Tokens", value: "\(settings.maxTokens)")
                Stepper(value: $settings.maxTokens, in: 16...768, step: 16) {
                    EmptyView()
                }
                .frame(width: 54)
            }
        }
    }
}

private struct ControlLabel: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(CabinetPalette.paperDeep)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(CabinetPalette.lamp)
        }
        .font(.caption)
    }
}

private struct ContextPanel: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Context", selection: $store.contextMode) {
                ForEach(ContextMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 7) {
                MetricRow(label: "Mode", value: store.contextMode.caption)
                MetricRow(label: "Estimate", value: "~\(store.contextEstimate) / \(store.contextBudget)")
                MetricRow(label: "Pinned", value: "\(store.pinnedMessageIDs.count)")
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CabinetPalette.nickel.opacity(0.20))
                    Capsule()
                        .fill(store.contextFill > 0.70 ? CabinetPalette.lamp : CabinetPalette.signal.opacity(0.85))
                        .frame(width: max(8, geometry.size.width * store.contextFill))
                }
            }
            .frame(height: 6)

            Button {
                store.showPayloadPreview.toggle()
            } label: {
                Label("Preview payload", systemImage: "doc.plaintext")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(CabinetPalette.brass)
        }
    }
}

private struct FindingPanel: View {
    @EnvironmentObject private var store: ChatStore
    private let tags = ["good", "slow", "rambling", "off-task", "repeat", "baseline"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        store.toggleFindingTag(tag)
                    } label: {
                        Text(tag)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(store.findingTags.contains(tag) ? CabinetPalette.inkOnPaper : CabinetPalette.paperDeep)
                    .background {
                        Capsule()
                            .fill(store.findingTags.contains(tag) ? CabinetPalette.lamp.opacity(0.92) : CabinetPalette.nickel.opacity(0.12))
                    }
                }
            }

            TextEditor(text: $store.findingNote)
                .font(.caption)
                .scrollContentBackground(.hidden)
                .foregroundStyle(CabinetPalette.paperLight)
                .padding(8)
                .frame(minHeight: 94)
                .background {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(.black.opacity(0.20))
                        .stroke(CabinetPalette.nickel.opacity(0.15), lineWidth: 1)
                }
        }
    }
}
