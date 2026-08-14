import SwiftUI
import StoreKit

struct PaywallView: View {
    @State private var purchase = PurchaseService.shared
    @State private var selectedTier: PurchaseService.ProductID = .yearly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showRestoreNotice = false
    @State private var showPendingNotice = false
    @State private var hasAttemptedLoad = false
    @State private var yearlyTrialText: String?
    @State private var monthlyTrialText: String?
    @State private var restoreFailed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                // Tiers come BEFORE the comparison table so the choice is on the
                // first screen; the button itself never scrolls (see purchaseBar).
                ScrollView {
                    VStack(spacing: CaelynSpacing.md) {
                        titleBlock
                        if productsAreReady {
                            tierCards
                        } else if !hasAttemptedLoad || purchase.isLoadingProducts {
                            loadingState
                        } else {
                            unavailableState
                        }
                        benefitStack
                        freeTierNote
                    }
                    .padding(.horizontal, CaelynSpacing.lg)
                    .padding(.top, CaelynSpacing.xs)
                    .padding(.bottom, CaelynSpacing.md)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    }
                    .accessibilityLabel("Close")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            // A review prompt in the same session as a paywall reads as pressure (mon-7).
            RatingService.suppressForThisSession()
            await purchase.loadProducts()
            if let yearly = purchase.yearlyProduct {
                yearlyTrialText = await purchase.freeTrialLabel(for: yearly)
            }
            if let monthly = purchase.monthlyProduct {
                monthlyTrialText = await purchase.freeTrialLabel(for: monthly)
            }
            hasAttemptedLoad = true
        }
        .alert("Purchase failed", isPresented: errorBinding) {
            Button("OK") { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
        .alert("Restore failed", isPresented: $restoreFailed) {
            Button("OK") { restoreFailed = false }
        } message: {
            Text("Couldn't reach the App Store to restore your purchases. Check your connection and try again.")
        }
        .alert("Restored", isPresented: $showRestoreNotice) {
            Button("OK") { showRestoreNotice = false }
        } message: {
            Text(purchase.isPro
                 ? "You're all set with Caelyn Pro."
                 : "No active Caelyn Pro subscription was found on this Apple ID.")
        }
        .alert("Purchase Pending", isPresented: $showPendingNotice) {
            Button("OK") { showPendingNotice = false }
        } message: {
            Text("Your purchase is awaiting approval — for example, if parental controls are enabled. Caelyn Pro will unlock automatically once it's approved.")
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                CaelynColor.backgroundCream,
                CaelynColor.lavender.opacity(0.35),
                CaelynColor.blush.opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Title

    /// A small sparkle mark instead of the old 128pt circle collage: the plans
    /// have to be visible without scrolling, and decoration was eating the space
    /// the decision needed.
    private var titleBlock: some View {
        VStack(spacing: CaelynSpacing.xs) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CaelynColor.lavender, CaelynColor.blush],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .light))
                    .foregroundStyle(CaelynColor.primaryPlum)
            }
            .accessibilityHidden(true)

            Text("Caelyn Pro")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CaelynColor.deepPlumText)
            Text("Everything Caelyn learns about you, in full.")
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, CaelynSpacing.xs)
    }

    // MARK: - Benefits

    /// Four benefits, not an eleven-row comparison grid. Research on subscription
    /// paywalls is consistent that a short value stack converts better than a
    /// feature matrix, and the matrix was the single biggest thing standing
    /// between her and the buy button.
    private var benefitStack: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
            Text("What Pro adds")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
            benefitRow("chart.line.uptrend.xyaxis", "Every pattern Caelyn finds",
                       "Not just the first five.", CaelynColor.lavender)
            benefitRow("heart.text.square.fill", "Trying to conceive & pregnancy",
                       "Fertility, pregnancy and postpartum modes.", CaelynColor.blush)
            benefitRow("stethoscope", "Doctor-ready PDF",
                       "Your history, ready for an appointment.", CaelynColor.sage.opacity(0.6))
            benefitRow("applewatch", "Watch & lock screen",
                       "Your cycle at a glance.", CaelynColor.warmSand)
        }
    }

    private func benefitRow(_ icon: String, _ title: String, _ detail: String, _ tint: Color) -> some View {
        HStack(spacing: CaelynSpacing.sm) {
            ZStack {
                Circle().fill(tint).frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.8))
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(CaelynFont.subheadline.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText)
                Text(detail)
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Keeps the honest half of the old comparison table in one line: the free
    /// app is not crippled, and saying so is part of the brand.
    private var freeTierNote: some View {
        Text("Tracking, predictions, reminders and export stay free — always.\nYour data stays on this device either way.")
            .font(CaelynFont.caption)
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Plans

    /// Yearly first, then Monthly, then Lifetime. Leading with the annual plan
    /// and showing its per-month equivalent is the standard anchor: it makes the
    /// yearly price legible in monthly terms rather than looking like a bigger
    /// number. Three options is also the ceiling — beyond that, choosing gets
    /// harder and more people leave without picking anything.
    private var tierCards: some View {
        VStack(spacing: CaelynSpacing.xs) {
            PaywallTierCard(
                kind: .yearly,
                displayPrice: yearlyDisplayPrice,
                unitLabel: "per year",
                subLabel: yearlySubLabel,
                badgeText: yearlyTrialText != nil ? "FREE TRIAL" : yearlySavingsBadgeText,
                badgeBackground: CaelynColor.successSage,
                isSelected: selectedTier == .yearly
            ) {
                selectedTier = .yearly
                Haptics.selection()
            }

            PaywallTierCard(
                kind: .monthly,
                displayPrice: monthlyDisplayPrice,
                unitLabel: "per month",
                subLabel: monthlyTrialText ?? "Cancel anytime",
                badgeText: nil,
                badgeBackground: .clear,
                isSelected: selectedTier == .monthly
            ) {
                selectedTier = .monthly
                Haptics.selection()
            }

            // Lifetime leans into local-only: nothing recurring, nothing in the
            // cloud. Shown only if it actually loaded (mon-3).
            if purchase.lifetimeProduct != nil {
                PaywallTierCard(
                    kind: .lifetime,
                    displayPrice: lifetimeDisplayPrice,
                    unitLabel: "once",
                    subLabel: "One payment, nothing recurring",
                    badgeText: "FOREVER",
                    badgeBackground: CaelynColor.primaryPlum,
                    isSelected: selectedTier == .lifetime
                ) {
                    selectedTier = .lifetime
                    Haptics.selection()
                }
            }
        }
    }

    /// "Just $1.67 a month · 7-day free trial" — the per-month framing first,
    /// since that's the number she compares against the monthly plan.
    private var yearlySubLabel: String? {
        let perMonth = yearlyPerMonthLabel
        switch (perMonth, yearlyTrialText) {
        case let (.some(p), .some(trial)): return "\(p) · \(trial)"
        case let (.some(p), nil):          return p
        case let (nil, .some(trial)):      return trial
        default:                           return nil
        }
    }

    // MARK: - Purchase bar (pinned)

    /// The pay button must never be something she has to go looking for, so it
    /// lives in a bottom inset rather than at the end of the scroll. The
    /// auto-renew disclosure rides with it — App Review 3.1.2 expects the terms
    /// to be visible alongside the purchase, and here they always are.
    private var purchaseBar: some View {
        VStack(spacing: CaelynSpacing.xs) {
            if productsAreReady {
                ctaButton
            }
            trustCopy
            footerLinks
        }
        .padding(.horizontal, CaelynSpacing.lg)
        .padding(.top, CaelynSpacing.sm)
        .padding(.bottom, CaelynSpacing.xs)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CaelynColor.deepPlumText.opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        VStack(spacing: 6) {
            Button(action: { Task { await beginPurchase() } }) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(ctaTitle)
                        .font(CaelynFont.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CaelynSpacing.md)
                .padding(.horizontal, CaelynSpacing.lg)
                .foregroundStyle(.white)
                .background(CaelynColor.primaryPlum, in: RoundedRectangle(cornerRadius: CaelynRadius.button, style: .continuous))
                .opacity(purchase.isPro ? 0.5 : (isPurchasing ? 0.8 : 1.0))   // dim when already Pro (mon-6)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || selectedProduct == nil || purchase.isPro)
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: CaelynSpacing.md) {
            Button("Restore purchases") { Task { await runRestore() } }
                .font(CaelynFont.subheadline.weight(.medium))
                .foregroundStyle(CaelynColor.primaryPlum)
            Spacer()
            Link("Privacy", destination: AppURLs.privacyPolicy)
                .font(CaelynFont.subheadline.weight(.medium))
                .foregroundStyle(CaelynColor.primaryPlum)
            Link("Terms", destination: AppURLs.termsOfUse)
                .font(CaelynFont.subheadline.weight(.medium))
                .foregroundStyle(CaelynColor.primaryPlum)
        }
        .padding(.horizontal, 4)
    }

    private var trustCopy: some View {
        Text(disclosureText)
            .font(CaelynFont.caption)
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Empty / loading states

    // Require BOTH subscription tiers before showing the picker, so a tier card can
    // never appear selected-but-unpurchasable when only one product loads (mon-6).
    // Lifetime is optional and shown only when it also loads.
    private var productsAreReady: Bool {
        purchase.monthlyProduct != nil && purchase.yearlyProduct != nil
    }

    private var loadingState: some View {
        CaelynCard(padding: CaelynSpacing.lg) {
            HStack(spacing: CaelynSpacing.sm) {
                ProgressView().tint(CaelynColor.primaryPlum)
                Text("Loading subscription options…")
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
            }
        }
    }

    /// Transient error state — shown only when StoreKit failed to load real
    /// App Store products. NOT a "feature unavailable" state. Subscribed
    /// users on this device can still tap Restore Purchases (in the footer)
    /// to recover their entitlement without needing products to load first.
    private var unavailableState: some View {
        CaelynCard(padding: CaelynSpacing.lg) {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(CaelynColor.alertRose)
                    Text("Couldn't load subscription options")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                }
                Text("Check your internet connection and try again. If you've already subscribed on another device, tap Restore purchases below.")
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await purchase.loadProducts() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try again")
                    }
                    .font(CaelynFont.body.weight(.semibold))
                    .foregroundStyle(CaelynColor.primaryPlum)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Computed

    private var selectedProduct: Product? {
        switch selectedTier {
        case .monthly:  return purchase.monthlyProduct
        case .yearly:   return purchase.yearlyProduct
        case .lifetime: return purchase.lifetimeProduct
        }
    }

    private var ctaTitle: String {
        if purchase.isPro { return "You're already Pro" }
        switch selectedTier {
        case .monthly:  return isPurchasing ? "Subscribing…" : (monthlyTrialText != nil ? "Start free trial" : "Continue with Monthly")
        case .yearly:   return isPurchasing ? "Subscribing…" : (yearlyTrialText != nil ? "Start free trial" : "Continue with Yearly")
        case .lifetime: return isPurchasing ? "Purchasing…" : "Buy Lifetime"
        }
    }

    private var lifetimeDisplayPrice: String {
        guard let product = purchase.lifetimeProduct else { return "—" }
        return product.displayPrice
    }

    /// All price-display computeds below are only rendered when
    /// `productsAreReady` is true (see body), so the nil branches are
    /// unreachable from the UI today. We still return neutral placeholders
    /// instead of guessed prices so a future refactor that drops the gate
    /// can never show stale or inaccurate marketing prices.
    private var monthlyDisplayPrice: String {
        guard let product = purchase.monthlyProduct else { return "—" }
        return product.displayPrice
    }

    private var yearlyDisplayPrice: String {
        guard let product = purchase.yearlyProduct else { return "—" }
        return product.displayPrice
    }

    private var yearlyPerMonthLabel: String? {
        guard let product = purchase.yearlyProduct else { return nil }
        let perMonth = product.price / 12
        return "Just \(formatPrice(perMonth, with: product)) a month"
    }

    private var yearlySavingsBadgeText: String {
        let percent = purchase.yearlySavingsPercent
        guard percent > 0 else { return "BEST VALUE" }
        return "SAVE \(percent)%"
    }

    private func formatPrice(_ value: Decimal, with product: Product) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = product.priceFormatStyle.currencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "—"
    }

    // MARK: - Actions

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )
    }

    private func beginPurchase() async {
        guard let product = selectedProduct, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        let outcome = await purchase.purchase(product)
        switch outcome {
        case .success:
            Haptics.success()
            dismiss()
        case .cancelled:
            break
        case .pending:
            showPendingNotice = true
        case .failed(let message):
            Haptics.warning()
            purchaseError = message
        }
    }

    private var disclosureText: String {
        switch selectedTier {
        case .lifetime:
            return "One payment. No subscription, no auto-renewal — yours on this Apple ID."
        case .monthly:
            let lead = monthlyTrialText.map { "\($0), then " } ?? ""
            return "\(lead)\(monthlyDisplayPrice)/month, auto-renewing until you cancel. Cancel anytime in iOS Settings."
        case .yearly:
            let lead = yearlyTrialText.map { "\($0), then " } ?? ""
            return "\(lead)\(yearlyDisplayPrice)/year, auto-renewing until you cancel. Cancel anytime in iOS Settings."
        }
    }

    private func runRestore() async {
        await purchase.restore()
        // Distinguish a genuine failure (network) from "nothing to restore" so we
        // don't tell a user with a connection error that they have no subscription (mon-6).
        if purchase.lastError != nil && !purchase.isPro {
            restoreFailed = true
        } else {
            showRestoreNotice = true
        }
    }
}

#Preview {
    PaywallView()
}
