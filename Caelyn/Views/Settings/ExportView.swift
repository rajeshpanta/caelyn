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
                VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                    introCard
                    rangeSection
                    formatSection
                    optionsSection
                    actionSection
                    if let error = generationError {
                        errorBanner(error)
                    }
                }
                .padding(CaelynSpacing.lg)
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Export data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CaelynColor.primaryPlum)
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
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                ZStack {
                    Circle().fill(CaelynColor.lavender).frame(width: CaelynIconSize.lg, height: CaelynIconSize.lg)
                    Image(systemName: "tray.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Take your data with you")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text("Caelyn generates the file on this device. Nothing leaves until you share it.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            sectionTitle("Range")
            CaelynCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(ExportRange.allCases) { option in
                        rangeRow(option)
                        if option != ExportRange.allCases.last {
                            Rectangle()
                                .fill(CaelynColor.deepPlumText.opacity(0.06))
                                .frame(height: 1)
                                .padding(.leading, CaelynSpacing.md)
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
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText)
                Spacer()
                if range == option {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
            }
            .padding(CaelynSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            sectionTitle("Format")
            HStack(spacing: CaelynSpacing.sm) {
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
                            .background(CaelynColor.primaryPlum, in: Circle())
                            .offset(x: 14, y: -10)
                    }
                }
                Text(option.displayName)
                    .font(CaelynFont.callout.weight(.semibold))
                if locked {
                    Text("PRO")
                        .font(CaelynFont.caption.weight(.bold))
                        .tracking(0.5)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(.white)
                        .background(CaelynColor.primaryPlum, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .foregroundStyle(format == option ? .white : CaelynColor.primaryPlum)
            .background(
                format == option ? CaelynColor.primaryPlum : CaelynColor.cardWhite,
                in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                    .stroke(format == option ? CaelynColor.primaryPlum : CaelynColor.deepPlumText.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
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
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .medium))
                Text("\(filteredEntries.count) entr\(filteredEntries.count == 1 ? "y" : "ies") in this range")
                    .font(CaelynFont.subheadline)
            }
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))

            if let url = generatedURL {
                ShareLink(item: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share \(format.displayName)")
                    }
                    .font(CaelynFont.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CaelynSpacing.md)
                    .padding(.horizontal, CaelynSpacing.lg)
                    .foregroundStyle(.white)
                    .background(CaelynColor.primaryPlum, in: RoundedRectangle(cornerRadius: CaelynRadius.button, style: .continuous))
                }
                CaelynButton(title: "Generate again", variant: .tertiary) { generate() }
            } else {
                CaelynButton(title: "Generate \(format.displayName)", variant: .primary, icon: "doc.badge.gearshape") {
                    generate()
                }
                .disabled(filteredEntries.isEmpty)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.alertRose.opacity(0.12)) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(CaelynColor.alertRose)
                Text(message)
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(CaelynFont.caption.weight(.semibold))
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
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
