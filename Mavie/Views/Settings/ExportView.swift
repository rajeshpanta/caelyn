import SwiftUI
import SwiftData

struct ExportView: View {
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @Query private var profiles: [UserProfile]
    @Environment(\.dismiss) private var dismiss

    @State private var purchase = PurchaseService.shared
    @State private var range: ExportRange = .last3Months
    @State private var format: ExportFormat = .csv
    @State private var includeNotes: Bool = true
    @State private var generatedURL: URL?
    @State private var generationError: String?
    @State private var showingPaywall = false

    private var profile: UserProfile? { profiles.first }
    private var filteredEntries: [CycleEntry] {
        ExportService.filterEntries(entries, range: range)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                    introCard
                    rangeSection
                    formatSection
                    optionsSection
                    actionSection
                    if let error = generationError {
                        errorBanner(error)
                    }
                }
                .padding(MavieSpacing.lg)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Export data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(MavieColor.primaryPlum)
                }
            }
            .onChange(of: range) { _, _ in resetGeneration() }
            .onChange(of: format) { _, _ in resetGeneration() }
            .onChange(of: includeNotes) { _, _ in resetGeneration() }
        }
        .sheet(isPresented: $showingPaywall) { PaywallView() }
    }

    // MARK: - Sections

    private var introCard: some View {
        MavieCard(padding: MavieSpacing.md) {
            HStack(alignment: .top, spacing: MavieSpacing.sm) {
                ZStack {
                    Circle().fill(MavieColor.lavender).frame(width: 36, height: 36)
                    Image(systemName: "tray.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(MavieColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Take your data with you")
                        .font(MavieFont.headline)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text("Mavie generates the file on this device. Nothing leaves until you share it.")
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            sectionTitle("Range")
            MavieCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(ExportRange.allCases) { option in
                        rangeRow(option)
                        if option != ExportRange.allCases.last {
                            Rectangle()
                                .fill(MavieColor.deepPlumText.opacity(0.06))
                                .frame(height: 1)
                                .padding(.leading, MavieSpacing.md)
                        }
                    }
                }
            }
        }
    }

    private func rangeRow(_ option: ExportRange) -> some View {
        Button {
            range = option
        } label: {
            HStack {
                Text(option.displayName)
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText)
                Spacer()
                if range == option {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MavieColor.primaryPlum)
                }
            }
            .padding(MavieSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            sectionTitle("Format")
            HStack(spacing: MavieSpacing.sm) {
                ForEach(ExportFormat.allCases) { option in
                    formatChip(option)
                }
            }
        }
    }

    private func formatChip(_ option: ExportFormat) -> some View {
        let locked = (option == .pdf) && !purchase.isPro
        return Button {
            if locked {
                showingPaywall = true
            } else {
                format = option
                Haptics.selection()
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: option.systemIcon)
                        .font(.system(size: 22, weight: .medium))
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(MavieColor.primaryPlum, in: Circle())
                            .offset(x: 14, y: -10)
                    }
                }
                Text(option.displayName)
                    .font(MavieFont.callout.weight(.semibold))
                if locked {
                    Text("PRO")
                        .font(MavieFont.caption.weight(.bold))
                        .tracking(0.5)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(.white)
                        .background(MavieColor.primaryPlum, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .foregroundStyle(format == option ? .white : MavieColor.primaryPlum)
            .background(
                format == option ? MavieColor.primaryPlum : MavieColor.cardWhite,
                in: RoundedRectangle(cornerRadius: MavieRadius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MavieRadius.card, style: .continuous)
                    .stroke(format == option ? MavieColor.primaryPlum : MavieColor.deepPlumText.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            sectionTitle("Options")
            ToggleCard(
                title: "Include private notes",
                subtitle: "Notes you've added to logged days will appear in the export.",
                icon: "text.alignleft",
                isOn: $includeNotes
            )
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .medium))
                Text("\(filteredEntries.count) entr\(filteredEntries.count == 1 ? "y" : "ies") in this range")
                    .font(MavieFont.subheadline)
            }
            .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))

            if let url = generatedURL {
                ShareLink(item: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share \(format.displayName)")
                    }
                    .font(MavieFont.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MavieSpacing.md)
                    .padding(.horizontal, MavieSpacing.lg)
                    .foregroundStyle(.white)
                    .background(MavieColor.primaryPlum, in: RoundedRectangle(cornerRadius: MavieRadius.button, style: .continuous))
                }
                MavieButton(title: "Generate again", variant: .tertiary) { generate() }
            } else {
                MavieButton(title: "Generate \(format.displayName)", variant: .primary, icon: "doc.badge.gearshape") {
                    generate()
                }
                .disabled(filteredEntries.isEmpty)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        MavieCard(padding: MavieSpacing.md, background: MavieColor.alertRose.opacity(0.12)) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(MavieColor.alertRose)
                Text(message)
                    .font(MavieFont.subheadline)
                    .foregroundStyle(MavieColor.deepPlumText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(MavieFont.caption.weight(.semibold))
            .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
            .tracking(0.6)
    }

    // MARK: - Generation

    private func resetGeneration() {
        generatedURL = nil
        generationError = nil
    }

    private func generate() {
        do {
            let data: Data
            switch format {
            case .csv:
                data = ExportService.generateCSV(entries: filteredEntries, includeNotes: includeNotes).data(using: .utf8) ?? Data()
            case .pdf:
                data = ExportService.generatePDF(entries: filteredEntries, profile: profile, range: range, includeNotes: includeNotes)
            }
            let url = try ExportService.writeToTempFile(data: data, format: format, range: range)
            generatedURL = url
            generationError = nil
        } catch {
            generationError = "Couldn't generate the export — \(error.localizedDescription)"
        }
    }
}

#Preview {
    ExportView()
        .modelContainer(Persistence.preview)
}
