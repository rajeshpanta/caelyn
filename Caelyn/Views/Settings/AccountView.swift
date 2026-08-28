import AuthenticationServices
import StoreKit
import SwiftData
import SwiftUI

/// Account, name, and iCloud sync — the one screen where all three live.
///
/// The whole screen is written to be declinable. Nothing here is required to use
/// Caelyn, nothing here is a wall in front of her history, and the copy says so
/// rather than implying it. There is no "Sign up to continue", no benefit locked
/// behind an account, and no dark pattern where the decline button is quieter than
/// the accept.
struct AccountView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    private var profile: UserProfile? { profiles.first }

    @State private var signInService = AppleSignInService()
    @State private var isSignedIn = AccountIdentityStore.isSignedIn
    @State private var availability: CloudAvailability = .unreachable
    @State private var syncOn = Persistence.isSyncEnabled

    @State private var nameDraft = ""
    @State private var isEditingName = false
    @FocusState private var nameFieldFocused: Bool

    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showDeleteCloudConfirm = false
    @State private var needsRelaunchNotice = false
    @State private var cloudDeletionResult: String?
    @State private var isDeletingCloud = false
    @State private var purchase = PurchaseService.shared
    @State private var namePrompt: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                headline
                nameCard
                accountCard
                syncCard
                cloudCopyCard
                if isSignedIn { manageCard }
                reassurance
            }
            .padding(.horizontal, CaelynSpacing.lg)
            .padding(.top, CaelynSpacing.md)
            .padding(.bottom, CaelynSpacing.xl)
        }
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
        .navigationTitle("Account & iCloud")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            availability = await CloudAccount.availability()
            isSignedIn = AccountIdentityStore.isSignedIn
            nameDraft = profile?.preferredName ?? ""
        }
        .sheet(item: Binding(
            get: { namePrompt.map(NamePrompt.init(prefill:)) },
            set: { if $0 == nil { namePrompt = nil } }
        )) { prompt in
            PreferredNameStep(prefill: prompt.prefill) { confirmed in
                AccountSession.setPreferredName(confirmed, on: profile)
                modelContext.saveOrLog()
                nameDraft = profile?.preferredName ?? ""
                namePrompt = nil
            }
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Keep your Caelyn\nhistory with you")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(CaelynColor.deepPlumText)
            Text("Two separate things, and both are optional. A name so Caelyn can say hello properly, and your own private iCloud so your history follows you to a new iPhone.")
                .font(CaelynFont.body)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Name

    private var nameCard: some View {
        SettingsSectionCard(title: "What should Caelyn call you?") {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(spacing: CaelynSpacing.sm) {
                    TextField("Your name", text: $nameDraft)
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFieldFocused)
                        .onSubmit(saveName)
                        .accessibilityIdentifier("UIA.Account.NameField")

                    if nameFieldFocused || nameDraft != (profile?.preferredName ?? "") {
                        Button("Save", action: saveName)
                            .font(CaelynFont.callout.weight(.semibold))
                            .foregroundStyle(CaelynColor.primaryPlum)
                            .accessibilityIdentifier("UIA.Account.SaveName")
                    }
                }
                .padding(CaelynSpacing.md)

                Text(namePreview)
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    .padding(.horizontal, CaelynSpacing.md)
                    .padding(.bottom, CaelynSpacing.md)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Shows her exactly what the home screen will say, including the honest
    /// nameless version when there's nothing usable to greet her by.
    private var namePreview: String {
        if let name = PersonalName.usable(nameDraft) {
            return "Caelyn will say: \u{201C}\(HomeCopy.greeting(name: name))\u{201D}"
        }
        return "Leave this empty and Caelyn just says \u{201C}\(HomeCopy.greeting())\u{201D} \u{2014} which is lovely too."
    }

    private func saveName() {
        AccountSession.setPreferredName(nameDraft, on: profile)
        nameDraft = profile?.preferredName ?? ""
        nameFieldFocused = false
        modelContext.saveOrLog()
        Haptics.success()
    }

    // MARK: - Sign in with Apple

    @ViewBuilder
    private var accountCard: some View {
        SettingsSectionCard(title: "Caelyn account") {
            VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                if isSignedIn {
                    HStack(spacing: CaelynSpacing.md) {
                        badge("checkmark.seal.fill", CaelynColor.successSage)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signed in with Apple")
                                .font(CaelynFont.headline)
                                .foregroundStyle(CaelynColor.deepPlumText)
                            Text("Caelyn knows you as a random ID from Apple \u{2014} not your email, and not your name unless you told us.")
                                .font(CaelynFont.subheadline)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    Text("Signing in is optional. It gives Caelyn a name to greet you by and an identity that survives reinstalling \u{2014} it is not how your data is stored, and everything works perfectly without it.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)

                    SignInWithAppleButton(.signIn) { _ in
                        // Scopes are configured inside AppleSignInService so there
                        // is exactly one place that decides what Caelyn asks for.
                    } onCompletion: { _ in }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
                        .allowsHitTesting(false)
                        .overlay {
                            Button(action: signIn) { Color.clear.contentShape(Rectangle()) }
                                .accessibilityLabel("Sign in with Apple")
                                .accessibilityIdentifier("UIA.Account.SignIn")
                        }

                    Text("You can keep using Caelyn without signing in.")
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                }
            }
            .padding(CaelynSpacing.md)
        }
    }

    private func signIn() {
        Task {
            let outcome = await signInService.signIn()
            // A cancellation is silent on purpose — she made a choice, and an
            // error banner would frame it as a mistake.
            if AccountSession.apply(outcome, to: profile) {
                modelContext.saveOrLog()
                isSignedIn = true
                nameDraft = profile?.preferredName ?? ""
                Haptics.success()
                // Asked once. A returning user who has already answered — here or
                // on another device that synced — signs straight in.
                if AccountSession.needsNameConfirmation(profile) {
                    namePrompt = AccountSession.namePrefill(for: profile)
                }
            }
        }
    }

    // MARK: - iCloud sync

    private var syncCard: some View {
        SettingsSectionCard(title: "Private iCloud sync") {
            VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                SettingsToggleRow(
                    icon: "icloud",
                    iconColor: CaelynColor.primaryPlum,
                    title: "Sync with my iCloud",
                    subtitle: "Your own private iCloud \u{2014} never a Caelyn server",
                    isOn: Binding(
                        get: { syncOn },
                        set: { setSync($0) }
                    ),
                    disabled: !availability.canEnableSync && !syncOn
                )
                .accessibilityIdentifier("UIA.Account.SyncToggle")

                Text(statusLine)
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CaelynSpacing.md)

                if needsRelaunchNotice {
                    Text("Reopen Caelyn to finish switching this on. Nothing is lost in the meantime \u{2014} your history is right here on this iPhone.")
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.primaryPlum)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, CaelynSpacing.md)
                        .padding(.bottom, CaelynSpacing.md)
                }
            }
        }
    }

    /// What she is told about sync.
    ///
    /// Reads `Persistence.isSyncActive` — whether the mirrored store actually
    /// opened — and never the preference alone. Claiming "backed up" while the
    /// container failed to open would be telling her that her history is safe
    /// somewhere it is not.
    private var statusLine: String {
        guard syncOn else {
            return "Off. Everything stays on this iPhone, exactly as it always has."
        }
        if Persistence.isSyncActive { return availability.message }
        return "Waiting to start. \(availability.message)"
    }

    private func setSync(_ on: Bool) {
        syncOn = on
        UserDefaults.standard.set(on, forKey: Persistence.syncEnabledKey)
        if on {
            // She has changed her mind after deleting a cloud copy. Clearing the
            // marker is what stops the launch-time guard from deleting the new copy
            // she has just asked for.
            CloudDataDeletion.clearDeletionMarker()
            cloudDeletionResult = nil
        }
        // The container is built once per launch, so the switch takes effect on the
        // next one. Saying so is better than a toggle that appears to do nothing.
        needsRelaunchNotice = (on != Persistence.isSyncActive)
        Haptics.selection()
    }

    // MARK: - Managing the account (Apple requires deletion to be reachable in-app)

    /// Deleting the iCloud copy. Deliberately its own card, not a row tucked under
    /// the account, because it is not an account action: it is about her data, and
    /// someone who has never signed in can still have a cloud copy to remove.
    @ViewBuilder
    private var cloudCopyCard: some View {
        if showCloudCopyCard {
            SettingsSectionCard(title: "Your iCloud copy") {
                VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                    if CloudDataDeletion.deletionIsPending {
                        Text("A deletion didn't finish, so your iCloud copy may still be there. Caelyn will try again \u{2014} or you can retry now.")
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.alertRose)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, CaelynSpacing.md)
                            .padding(.top, CaelynSpacing.md)
                    } else if CloudDataDeletion.cloudCopyWasDeleted && !syncOn {
                        Text("You deleted your iCloud copy. Caelyn won't make a new one unless you turn sync back on.")
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, CaelynSpacing.md)
                            .padding(.top, CaelynSpacing.md)
                    } else if !syncOn && CloudDataDeletion.cloudCopyMayExist {
                        // Sync off is not the same as no copy. Someone who synced
                        // for a month and then switched it off still has a month of
                        // history in iCloud, and needs to be told so — and given the
                        // button — rather than left assuming it went away with the
                        // toggle.
                        Text("Sync is off, but the copy Caelyn already made is still in your iCloud. Turning sync off stops new changes going up; it doesn't remove what's already there.")
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, CaelynSpacing.md)
                            .padding(.top, CaelynSpacing.md)
                    }

                    SettingsRow(
                        icon: "icloud.slash",
                        iconColor: CaelynColor.alertRose,
                        title: isDeletingCloud ? "Deleting\u{2026}" : "Delete my iCloud copy",
                        detail: nil,
                        action: { showDeleteCloudConfirm = true },
                        isDestructive: true
                    )
                    .disabled(isDeletingCloud)
                    .accessibilityIdentifier("UIA.Account.DeleteCloud")

                    Text("Removes the copy of your history stored in your private iCloud. What's on this iPhone stays exactly as it is \u{2014} this does not delete anything here.")
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, CaelynSpacing.md)
                        .padding(.bottom, CaelynSpacing.md)

                    if let cloudDeletionResult {
                        Text(cloudDeletionResult)
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, CaelynSpacing.md)
                            .padding(.bottom, CaelynSpacing.md)
                    }
                }
            }
            .confirmationDialog("Permanently delete your iCloud copy?",
                                isPresented: $showDeleteCloudConfirm, titleVisibility: .visible) {
                Button("Delete iCloud copy", role: .destructive) { deleteCloudCopy() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteCloudMessage)
            }
        }
    }

    /// Whether to offer cloud deletion at all.
    ///
    /// Deliberately not keyed on the sync toggle. It is shown whenever Caelyn has
    /// reason to believe a copy exists — currently syncing, a copy made earlier and
    /// sync since switched off, an unfinished deletion, or a completed one worth
    /// confirming. A user who has never successfully synced sees nothing, because
    /// for her there is genuinely nothing to delete.
    private var showCloudCopyCard: Bool {
        syncOn
            || CloudDataDeletion.cloudCopyMayExist
            || CloudDataDeletion.cloudCopyWasDeleted
            || CloudDataDeletion.deletionIsPending
    }

    private var deleteCloudMessage: String {
        let base = "This permanently removes your history from iCloud and cannot be undone. Your history on this iPhone is not deleted and Caelyn will keep working exactly as it does now."
        return syncOn
            ? base + " Sync will be turned off so no new copy is made."
            : base + " Sync stays off, so no new copy will be made."
    }

    private func deleteCloudCopy() {
        isDeletingCloud = true
        Task {
            let outcome = await CloudDataDeletion.deleteCloudCopy()
            cloudDeletionResult = outcome.message
            if outcome.didDelete { syncOn = false }
            isDeletingCloud = false
            if outcome.didDelete { Haptics.success() } else { Haptics.warning() }
        }
    }

    private var manageCard: some View {
        SettingsSectionCard(title: "Manage") {
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    iconColor: CaelynColor.primaryPlum,
                    title: "Sign out",
                    detail: "Keeps your history",
                    action: { showSignOutConfirm = true }
                )
                .accessibilityIdentifier("UIA.Account.SignOut")

                SettingsDivider()

                SettingsRow(
                    icon: "person.crop.circle.badge.xmark",
                    iconColor: CaelynColor.alertRose,
                    title: "Delete Caelyn account",
                    detail: nil,
                    action: { showDeleteAccountConfirm = true },
                    isDestructive: true
                )
                .accessibilityIdentifier("UIA.Account.DeleteAccount")

                VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                    Text("Deleting your account removes the Apple sign-in from Caelyn. It does **not** delete what you've logged \u{2014} that stays on this iPhone, and any iCloud copy stays too. Each of those is its own button, and each asks you separately.")

                    // Caelyn never receives a Sign in with Apple token, so there is
                    // nothing for it to revoke on her behalf. Removing the app from
                    // her Apple Account is something only she can do, and saying so
                    // is more honest than a button that silently does nothing.
                    Text("Caelyn only ever received an anonymous ID from Apple \u{2014} no tokens, no email \u{2014} so there's nothing for it to hand back. If you'd also like to remove Caelyn from your Apple Account, that's in iPhone Settings \u{2192} your name \u{2192} Sign in with Apple.")

                    if hasAutoRenewingSubscription {
                        Text("Deleting your account won't cancel your Caelyn Pro subscription \u{2014} Apple bills that, not Caelyn. Manage or cancel it with Apple if you don't want it to renew.")
                            .foregroundStyle(CaelynColor.alertRose)
                    }
                }
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .padding(CaelynSpacing.md)
            }
        }
        .confirmationDialog("Sign out of Caelyn?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everything you've logged stays on this iPhone. You can sign back in any time.")
        }
        .confirmationDialog("Delete your Caelyn account?", isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
            // Apple's account-deletion guidance: where an auto-renewable
            // subscription exists, tell her billing continues and give her the way
            // to cancel before she goes ahead.
            if hasAutoRenewingSubscription {
                Button("Manage subscription") { openSubscriptionManagement() }
            }
            Button("Delete account", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteAccountMessage)
        }
    }

    private func signOut() {
        AccountSession.signOut(profile: profile)
        modelContext.saveOrLog()
        isSignedIn = false
    }

    /// Deleting the identity. Deliberately **not** a data deletion.
    ///
    /// Apple requires an in-app way to delete an account once you offer one. It
    /// does not require, and Caelyn will not perform, the destruction of her
    /// reproductive health history as a side effect of that. The two live behind
    /// two separate confirmations in two separate places, and this one says plainly
    /// what it does not do.
    /// True when Apple is billing her on a renewing basis. Lifetime is a one-off
    /// purchase and needs no warning.
    private var hasAutoRenewingSubscription: Bool {
        purchase.purchasedProductIDs.contains(PurchaseService.ProductID.monthly.rawValue)
            || purchase.purchasedProductIDs.contains(PurchaseService.ProductID.yearly.rawValue)
    }

    private var deleteAccountMessage: String {
        let base = "This removes your Apple sign-in from Caelyn. Your cycle history is not deleted \u{2014} it stays on this iPhone, your iCloud copy stays too, and you'll still be able to open and use Caelyn exactly as before. Deleting either of those is a separate choice."
        guard hasAutoRenewingSubscription else { return base }
        return base + "\n\nDeleting your account does not cancel your Caelyn Pro subscription. Apple bills that, not Caelyn, and it keeps renewing until you cancel it with Apple."
    }

    /// Apple's guidance names two routes: `showManageSubscription` on iOS 15+, or
    /// the apps.apple.com link. Caelyn targets iOS 17, so the native sheet is the
    /// right one — it keeps her inside Caelyn mid-decision instead of throwing her
    /// out to the App Store app. The documented URL stays as the fallback for the
    /// case where no foreground scene can be resolved.
    private func openSubscriptionManagement() {
        Task {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            if let scene {
                try? await AppStore.showManageSubscriptions(in: scene)
            } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                await UIApplication.shared.open(url)
            }
        }
    }

    private func deleteAccount() {
        AccountSession.signOut(profile: profile)
        profile?.appleSuggestedName = nil
        modelContext.saveOrLog()
        isSignedIn = false
    }

    // MARK: - Reassurance

    private var reassurance: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Where this goes")
                    .font(CaelynFont.caption.weight(.semibold))
                    .tracking(0.4)
            }
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))

            Text("Sync uses your own private iCloud database. There is still no Caelyn server and no Caelyn copy of your history \u{2014} we can't read it, because it never comes to us. Turning sync off leaves everything on this iPhone, right where it is.")
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CaelynSpacing.md)
        .background(CaelynColor.lavender.opacity(0.3), in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
    }

    private func badge(_ symbol: String, _ color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.15)).frame(width: CaelynIconSize.xl, height: CaelynIconSize.xl)
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
        }
    }
}
