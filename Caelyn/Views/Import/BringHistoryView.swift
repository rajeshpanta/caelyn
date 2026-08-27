import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// "Bring your history" — the whole switching experience, from picking where her
/// history lives to confirming what Caelyn found.
///
/// One screen that changes state rather than a stack of pushes, because the flow
/// is genuinely linear and a half-finished import should never be something she
/// can leave behind on a navigation stack and come back to later.
struct BringHistoryView: View {

    /// Set when the flow is opened by a file arriving from elsewhere — Files,
    /// Mail, another app's share sheet — so it starts by reading rather than by
    /// asking her where her history is.
    var incomingFile: IncomingImportFile?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    @State private var model = BringHistoryModel()
    @State private var guideSource: ImportSourceGuide?
    @State private var showingFilePicker = false
    @State private var showingUndoConfirm = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                    switch model.phase {
                    case .choosingSource:
                        introCard
                        sourceList
                    case .reading:
                        readingState
                    case .confirming, .importing:
                        confirmState
                    case .done(let outcome):
                        successState(outcome)
                    case .failed(let message):
                        failureState(message)
                    }
                    privacyFooter
                }
                .padding(CaelynSpacing.lg)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.phase)
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Bring your history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(model.isBusy ? "" : "Done") { dismiss() }
                        .foregroundStyle(CaelynColor.primaryPlum)
                        .disabled(model.isBusy)
                        .accessibilityIdentifier("UIA.Import.Close")
                }
            }
            .navigationDestination(item: $guideSource) { guide in
                ImportGuideView(guide: guide) {
                    guideSource = nil
                    // Where the instructions lead: a file she has to pick, or
                    // Apple Health once she has switched the other app's sync on.
                    if guide.needsAFile {
                        showingFilePicker = true
                    } else {
                        Task { await startAppleHealth(limitTo: guide.healthSourceFilter) }
                    }
                }
            }
        }
        .interactiveDismissDisabled(model.isBusy)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: BringHistoryView.readableTypes,
            allowsMultipleSelection: false
        ) { result in
            handlePickedFile(result)
        }
        .task {
            // A file that arrived from another app is read immediately; there is
            // nothing to choose, she already chose.
            guard let incomingFile else { return }
            await model.read(filename: incomingFile.filename, data: incomingFile.data, context: modelContext)
        }
    }

    /// What the file browser will let her pick.
    ///
    /// `.data` is included on purpose: a file emailed out of a support desk often
    /// arrives with no declared type at all, and refusing to *show* it would be a
    /// dead end she cannot debug. Caelyn decides whether it can read it after
    /// looking inside, and says so plainly if it can't.
    static let readableTypes: [UTType] = [.commaSeparatedText, .json, .plainText, .data]

    // MARK: - Choosing

    private var introCard: some View {
        CaelynCard {
            VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
                Text("You don't have to start over")
                    .font(CaelynFont.title3)
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("If you've been tracking somewhere else, bring it with you. Caelyn will show you what it found before anything is added, and nothing you've already logged here will change.")
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sourceList: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("WHERE IS IT NOW?")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)
            CaelynCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(ImportSourceGuide.pickable.enumerated()), id: \.element.key) { index, guide in
                        sourceRow(guide)
                        if index < ImportSourceGuide.pickable.count - 1 { SettingsDivider() }
                    }
                }
            }
        }
    }

    private func sourceRow(_ guide: ImportSourceGuide) -> some View {
        Button {
            if guide.hasInstructions {
                guideSource = guide
            } else {
                Task { await startAppleHealth(limitTo: guide.healthSourceFilter) }
            }
        } label: {
            HStack(spacing: CaelynSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(CaelynColor.primaryPlum.opacity(0.15))
                        .frame(width: CaelynIconSize.md, height: CaelynIconSize.md)
                    Image(systemName: guide.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(guide.title)
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(guide.subtitle)
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: CaelynSpacing.xs)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.3))
            }
            // A comfortable target regardless of how the text wraps at large sizes.
            .padding(CaelynSpacing.md)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("UIA.Import.Source.\(guide.key)")
        .accessibilityLabel("\(guide.title). \(guide.subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Reading

    private var readingState: some View {
        CaelynCard {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(spacing: CaelynSpacing.sm) {
                    ProgressView().tint(CaelynColor.primaryPlum)
                    Text("Reading your history…")
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText)
                }
                Text("Years of tracking can take a moment. Nothing has been added yet.")
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading your history. Nothing has been added yet.")
        .accessibilityIdentifier("UIA.Import.Reading")
    }

    // MARK: - Confirming

    @ViewBuilder
    private var confirmState: some View {
        if let preview = model.preview {
            ImportPreviewCard(preview: preview)

            if preview.hasChanges {
                VStack(spacing: CaelynSpacing.sm) {
                    CaelynButton(
                        title: model.phase == .importing ? "Adding…" : "Add to Caelyn",
                        variant: .primary,
                        icon: model.phase == .importing ? nil : "arrow.down.circle.fill"
                    ) {
                        model.confirm(context: modelContext)
                    }
                    .disabled(model.phase == .importing)
                    .accessibilityIdentifier("UIA.Import.Confirm")

                    CaelynButton(title: "Not now", variant: .tertiary) {
                        model.cancel()
                    }
                    .disabled(model.phase == .importing)
                    .accessibilityIdentifier("UIA.Import.Cancel")
                }
            } else {
                CaelynButton(title: "Choose a different file", variant: .secondary) {
                    model.cancel()
                }
                .accessibilityIdentifier("UIA.Import.Cancel")
            }
        }
    }

    // MARK: - Done

    @ViewBuilder
    private func successState(_ outcome: BringHistoryModel.ImportOutcome) -> some View {
        CaelynCard {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(spacing: CaelynSpacing.sm) {
                    Image(systemName: outcome.undone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(outcome.undone ? CaelynColor.deepPlumText.opacity(0.4) : CaelynColor.successSage)
                    Text(outcome.undone ? "Import undone" : "Your history is here")
                        .font(CaelynFont.title3)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(outcome.undone
                     ? "Everything that import added has been removed. Anything you'd edited since is still here."
                     : successDetail(outcome))
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("UIA.Import.Success")

        VStack(spacing: CaelynSpacing.sm) {
            CaelynButton(title: "Done", variant: .primary) { dismiss() }
                .accessibilityIdentifier("UIA.Import.Done")
            if !outcome.undone {
                CaelynButton(title: "Undo this import", variant: .tertiary) {
                    showingUndoConfirm = true
                }
                .accessibilityIdentifier("UIA.Import.Undo")
            }
        }
        .confirmationDialog(
            "Undo this import?",
            isPresented: $showingUndoConfirm,
            titleVisibility: .visible
        ) {
            Button("Undo import", role: .destructive) {
                model.undoLastImport(context: modelContext)
                Haptics.warning()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Caelyn will remove what this import added. Anything you've logged or edited yourself stays exactly as it is.")
        }
    }

    private func successDetail(_ outcome: BringHistoryModel.ImportOutcome) -> String {
        let amount = outcome.spanDescription
            ?? "\(outcome.summary.daysAffected) day\(outcome.summary.daysAffected == 1 ? "" : "s") of history"
        var parts = ["\(amount) added from \(outcome.sourceName)."]

        let found = ImportCopy.breakdown(outcome.summary)
        if !found.isEmpty { parts.append(sentence(ImportCopy.list(found))) }
        if outcome.summary.keptUserValue > 0 {
            parts.append("Your own entries were left untouched.")
        }
        parts.append("Your predictions now use this history.")
        return parts.joined(separator: " ")
    }

    /// Capitalise a fragment and end it, without upper-casing a whole string that
    /// may begin with a number.
    private func sentence(_ fragment: String) -> String {
        guard let first = fragment.first else { return fragment }
        return String(first).uppercased() + fragment.dropFirst() + "."
    }

    // MARK: - Failure

    private func failureState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.alertRose.opacity(0.12)) {
                HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(CaelynColor.alertRose)
                    Text(message)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("UIA.Import.Error")

            CaelynButton(title: "Try something else", variant: .secondary) {
                model.dismissError()
            }
            .accessibilityIdentifier("UIA.Import.Retry")
        }
    }

    private var privacyFooter: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "iphone")
                .font(.system(size: 11, weight: .semibold))
            Text("Your file is read on this iPhone. Nothing is uploaded, and Caelyn has no server to upload it to.")
                .font(CaelynFont.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
        .padding(.top, CaelynSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private func handlePickedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            // Cancelling the browser is reported here too; treat it as no-op.
            return
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await model.readFile(at: url, context: modelContext) }
        }
    }

    private func startAppleHealth(limitTo filter: HealthSyncService.SourceFilter? = nil) async {
        guard let profile else {
            model.dismissError()
            return
        }
        await model.readAppleHealth(profile: profile, context: modelContext, limitTo: filter)
    }
}

/// A file handed to Caelyn from outside — the share sheet or "Open in" route.
/// Carries bytes rather than a URL because by the time the flow presents, the
/// original location may no longer be readable.
struct IncomingImportFile: Identifiable, Equatable {
    let id = UUID()
    let filename: String
    let data: Data
}

/// Instructions for getting a file out of one particular app.
private struct ImportGuideView: View {
    let guide: ImportSourceGuide
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                CaelynCard {
                    VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
                        Text(guide.title)
                            .font(CaelynFont.title3)
                            .foregroundStyle(CaelynColor.deepPlumText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(guide.subtitle)
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !guide.steps.isEmpty {
                    VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                        Text("HOW TO GET IT")
                            .font(CaelynFont.caption.weight(.semibold))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                            .tracking(0.6)
                        CaelynCard {
                            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                                ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .firstTextBaseline, spacing: CaelynSpacing.sm) {
                                        Text("\(index + 1)")
                                            .font(CaelynFont.caption.weight(.bold))
                                            .foregroundStyle(CaelynColor.primaryPlum)
                                            .frame(width: 18, alignment: .trailing)
                                        Text(step)
                                            .font(CaelynFont.subheadline)
                                            .foregroundStyle(CaelynColor.deepPlumText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Step \(index + 1). \(step)")
                                }
                            }
                        }
                    }
                }

                if let note = guide.note {
                    CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.primaryPlum.opacity(0.08)) {
                        Text(note)
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                CaelynButton(
                    title: guide.actionLabel,
                    variant: .primary,
                    icon: guide.needsAFile ? "folder" : "heart.text.square"
                ) {
                    onContinue()
                }
                .accessibilityIdentifier("UIA.Import.ChooseFile")
            }
            .padding(CaelynSpacing.lg)
        }
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension ImportSourceGuide: Identifiable, Hashable {
    var id: String { key }
    static func == (lhs: ImportSourceGuide, rhs: ImportSourceGuide) -> Bool { lhs.key == rhs.key }
    func hash(into hasher: inout Hasher) { hasher.combine(key) }
}

#Preview {
    BringHistoryView()
        .modelContainer(Persistence.preview)
}

extension IncomingImportFile {
    /// Build from a URL iOS handed the app via "Open in" or the share sheet.
    ///
    /// The bytes are copied immediately, inside the security scope, because the
    /// scope is only guaranteed for the duration of this call. Returns nil when
    /// the file can't be read at all, which is the same outcome as a file she
    /// picks that turns out to be unreadable.
    init?(openedAt url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        self.init(filename: url.lastPathComponent, data: data)
    }
}
