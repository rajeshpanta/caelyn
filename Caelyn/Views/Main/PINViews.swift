import SwiftUI

// MARK: - PIN entry pad

/// A reusable numeric PIN pad. Fixed-length; auto-submits when the last digit is
/// entered. Used both to unlock (AppLockGate) and to set a PIN (PINSetupView).
struct PINPadView: View {
    let title: String
    let subtitle: String
    var length: Int = 4
    var errorMessage: String? = nil
    let onSubmit: (String) -> Void
    var onCancel: (() -> Void)? = nil

    @State private var entered = ""

    var body: some View {
        VStack(spacing: CaelynSpacing.lg) {
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(CaelynColor.primaryPlum)
                Text(title)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText)
                Text(subtitle)
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                ForEach(0..<length, id: \.self) { i in
                    Circle()
                        .fill(i < entered.count ? CaelynColor.primaryPlum : CaelynColor.deepPlumText.opacity(0.15))
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.top, CaelynSpacing.sm)

            Text(errorMessage ?? " ")
                .font(CaelynFont.subheadline)
                .foregroundStyle(CaelynColor.alertRose)
                .multilineTextAlignment(.center)

            pad

            if let onCancel {
                Button("Cancel") { onCancel() }
                    .font(CaelynFont.body.weight(.medium))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    .padding(.top, CaelynSpacing.sm)
            }
            Spacer(minLength: 0)
        }
        .padding(CaelynSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: errorMessage) { _, _ in entered = "" }   // clear digits when a new error arrives
    }

    private var pad: some View {
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        return VStack(spacing: CaelynSpacing.md) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: CaelynSpacing.lg) {
                    ForEach(rows[r], id: \.self) { key in keyButton(key) }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 70, height: 70)
        } else if key == "⌫" {
            Button {
                if !entered.isEmpty { entered.removeLast(); Haptics.selection() }
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                    .frame(width: 70, height: 70)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
        } else {
            Button { append(key) } label: {
                Text(key)
                    .font(.system(size: 30, weight: .regular, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .frame(width: 70, height: 70)
                    .background(Circle().fill(CaelynColor.lavender.opacity(0.5)))
            }
            .buttonStyle(.plain)
        }
    }

    private func append(_ digit: String) {
        guard entered.count < length else { return }
        entered.append(digit)
        Haptics.selection()
        if entered.count == length {
            let pin = entered
            entered = ""
            onSubmit(pin)
        }
    }
}

// MARK: - Set / confirm a PIN

/// Two-step "enter then confirm" flow for setting either the primary or the
/// duress PIN. Validates a duress PIN differs from the primary.
struct PINSetupView: View {
    enum Mode { case primary, duress }
    let mode: Mode
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .enter
    @State private var firstEntry = ""
    @State private var error: String?

    private enum Stage { case enter, confirm }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if mode == .duress, stage == .enter {
                    warning
                }
                PINPadView(
                    title: stage == .enter ? enterTitle : "Confirm your PIN",
                    subtitle: stage == .enter ? enterSubtitle : "Enter the same 4 digits again.",
                    length: 4,
                    errorMessage: error,
                    onSubmit: handle
                )
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle(mode == .primary ? "App PIN" : "Duress PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var enterTitle: String { mode == .primary ? "Set a PIN" : "Set a duress PIN" }
    private var enterSubtitle: String {
        mode == .primary ? "Choose a 4-digit code to unlock Caelyn." : "Choose a DIFFERENT 4-digit code."
    }

    private var warning: some View {
        HStack(alignment: .top, spacing: CaelynSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(CaelynColor.alertRose)
            Text("Entering this PIN instead of your normal one will permanently erase all Caelyn data, with no warning. Only set this if you understand the risk.")
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CaelynSpacing.md)
        .background(CaelynColor.alertRose.opacity(0.1), in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
        .padding(.horizontal, CaelynSpacing.lg)
        .padding(.top, CaelynSpacing.md)
    }

    private func handle(_ pin: String) {
        switch stage {
        case .enter:
            if mode == .duress, PINService.verify(pin) == .correct {
                error = "Your duress PIN must be different from your normal PIN."
                return
            }
            firstEntry = pin
            error = nil
            stage = .confirm
        case .confirm:
            guard pin == firstEntry else {
                error = "Those PINs didn't match. Let's try again."
                firstEntry = ""
                stage = .enter
                return
            }
            switch mode {
            case .primary: PINService.setPIN(pin)
            case .duress:  PINService.setDuressPIN(pin)
            }
            Haptics.success()
            onDone()
            dismiss()
        }
    }
}

// MARK: - Manage PIN (Settings entry point)

struct PINManageView: View {
    @State private var isSet = PINService.isSet
    @State private var hasDuress = PINService.hasDuress
    @State private var showingSetPrimary = false
    @State private var showingSetDuress = false

    var body: some View {
        List {
            Section {
                if isSet {
                    Button { showingSetPrimary = true } label: {
                        Label("Change PIN", systemImage: "key.fill")
                    }
                    Button(role: .destructive) { removePIN() } label: {
                        Label("Remove PIN", systemImage: "trash")
                    }
                } else {
                    Button { showingSetPrimary = true } label: {
                        Label("Set a PIN", systemImage: "lock.fill")
                    }
                }
            } footer: {
                Text("A PIN lets you unlock Caelyn without Face ID / Touch ID. It's stored only on this device.")
            }

            if isSet {
                Section {
                    if hasDuress {
                        Button(role: .destructive) { PINService.setDuressPIN(nil); hasDuress = false } label: {
                            Label("Remove duress PIN", systemImage: "trash")
                        }
                    } else {
                        Button { showingSetDuress = true } label: {
                            Label("Set a duress PIN", systemImage: "exclamationmark.shield.fill")
                        }
                    }
                } header: {
                    Text("Duress")
                } footer: {
                    Text("An optional second PIN that, if entered, silently and permanently erases all Caelyn data. For high-risk situations only.")
                }
            }
        }
        .navigationTitle("App PIN")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSetPrimary) {
            PINSetupView(mode: .primary) { isSet = PINService.isSet }
        }
        .sheet(isPresented: $showingSetDuress) {
            PINSetupView(mode: .duress) { hasDuress = PINService.hasDuress }
        }
    }

    private func removePIN() {
        PINService.clearAll()
        isSet = false
        hasDuress = false
    }
}
