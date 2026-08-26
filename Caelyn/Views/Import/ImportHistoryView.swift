import SwiftUI
import SwiftData

/// Every import she has made, and a way to take any of them back.
///
/// This exists because an import is the one action in Caelyn that changes a lot
/// of history at once. Being able to see "Imported from Clue · today" and undo it
/// is what makes trying an import a low-stakes decision instead of a leap.
struct ImportHistoryView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var batches: [ImportLedger.Batch] = []
    @State private var pendingUndo: ImportLedger.Batch?
    @State private var banner: String?

    private let ledger: ImportLedger

    init(ledger: ImportLedger = .shared) {
        self.ledger = ledger
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                if let banner {
                    CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.successSage.opacity(0.12)) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(CaelynColor.successSage)
                            Text(banner)
                                .font(CaelynFont.subheadline)
                                .foregroundStyle(CaelynColor.deepPlumText)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                    .accessibilityIdentifier("UIA.ImportHistory.Banner")
                }

                if batches.isEmpty {
                    emptyState
                } else {
                    batchList
                }
            }
            .padding(CaelynSpacing.lg)
        }
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
        .navigationTitle("Imports")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { batches = ledger.batches }
        .confirmationDialog(
            "Undo this import?",
            isPresented: Binding(get: { pendingUndo != nil }, set: { if !$0 { pendingUndo = nil } }),
            titleVisibility: .visible
        ) {
            Button("Undo import", role: .destructive) {
                if let batch = pendingUndo { undo(batch) }
                pendingUndo = nil
            }
            Button("Keep it", role: .cancel) { pendingUndo = nil }
        } message: {
            Text("Caelyn will remove what this import added. Anything you've logged or edited yourself stays exactly as it is, and other imports aren't affected.")
        }
    }

    private var emptyState: some View {
        CaelynCard {
            VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
                Text("Nothing imported yet")
                    .font(CaelynFont.body.weight(.medium))
                    .foregroundStyle(CaelynColor.deepPlumText)
                Text("When you bring history in from Apple Health or another app, it'll be listed here — and you'll be able to undo it.")
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("UIA.ImportHistory.Empty")
    }

    private var batchList: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("YOU CAN UNDO ANY OF THESE")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)
            CaelynCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(batches.enumerated()), id: \.element.id) { index, batch in
                        row(batch)
                        if index < batches.count - 1 { SettingsDivider() }
                    }
                }
            }
        }
    }

    private func row(_ batch: ImportLedger.Batch) -> some View {
        HStack(alignment: .top, spacing: CaelynSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("From \(batch.sourceName) · \(Self.when(batch.importedAt))")
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(batch.daysAffected) day\(batch.daysAffected == 1 ? "" : "s") of history")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
            }
            Spacer(minLength: CaelynSpacing.xs)
            Button("Undo") { pendingUndo = batch }
                .font(CaelynFont.callout.weight(.semibold))
                .foregroundStyle(CaelynColor.alertRose)
                .accessibilityIdentifier("UIA.ImportHistory.Undo")
                .accessibilityLabel("Undo import from \(batch.sourceName)")
        }
        .padding(CaelynSpacing.md)
        .frame(minHeight: 56)
    }

    private func undo(_ batch: ImportLedger.Batch) {
        let result = ImportPlanner.undo(batchID: batch.id, context: modelContext, ledger: ledger)
        guard result.succeeded else {
            banner = "That import couldn't be undone just now. Nothing was changed."
            return
        }
        Haptics.warning()
        batches = ledger.batches
        banner = "Removed what that import added. Everything you logged yourself is still here."
    }

    /// "today", "yesterday", or a plain date — never a raw timestamp.
    static func when(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ImportHistoryView()
            .modelContainer(Persistence.preview)
    }
}
