import SwiftUI
import StoreKit

struct PaywallView: View {
    @State private var purchase = PurchaseService.shared
    @State private var selectedTier: PurchaseService.ProductID = .yearly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showRestoreNotice = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: CaelynSpacing.lg) {
                        hero
                        titleBlock
                        featureSection
                        if productsAreReady {
                            tierCards
                            ctaButton
                        } else if purchase.isLoadingProducts {
                            loadingState
                        } else {
                            unavailableState
                        }
                        footerLinks
                        trustCopy
                    }
                    .padding(CaelynSpacing.lg)
                    .padding(.top, CaelynSpacing.sm)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.35))
                    }
                    .accessibilityLabel("Close")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await purchase.loadProducts() }
        .alert("Purchase failed", isPresented: errorBinding) {
            Button("OK") { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
        .alert("Restored", isPresented: $showRestoreNotice) {
            Button("OK") { showRestoreNotice = false }
        } message: {
            Text(purchase.isPro
                 ? "You're all set with Caelyn Pro."
                 : "No active Caelyn Pro subscription was found on this Apple ID.")
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

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            Circle().fill(CaelynColor.lavender).frame(width: 160, height: 160).offset(x: -44, y: -16)
            Circle().fill(CaelynColor.softRose.opacity(0.85)).frame(width: 140, height: 140).offset(x: 50, y: 16)
            Circle().fill(CaelynColor.sage.opacity(0.55)).frame(width: 100, height: 100).offset(x: -8, y: 60)
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(CaelynColor.primaryPlum.opacity(0.85))
                .offset(y: -8)
        }
        .frame(height: 200)
        .padding(.top, CaelynSpacing.sm)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Unlock Caelyn Pro")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(CaelynColor.deepPlumText)
                .multilineTextAlignment(.center)
            Text("Understand your body, deeper. With insights, reports, and reminders that grow with you.")
                .font(CaelynFont.body)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, CaelynSpacing.sm)
        }
    }

    // MARK: - Features

    /// Comparison only lists features that ship in this build AND are
    /// truthfully enforced. "Custom themes", "Yearly summary", "iCloud
    /// backup", and "Widgets" are deliberately omitted — they aren't
    /// implemented yet, and listing aspirational features in a paid-IAP
    /// comparison is a misrepresentation Apple Review will flag.
    private var featureSection: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            VStack(spacing: 0) {
                featureHeaderRow
                featureDivider
                featureRow("Period & cycle tracking", inFree: true, inPro: true)
                featureDivider
                featureRow("Cycle predictions", inFree: true, inPro: true)
                featureDivider
                featureRow("Symptom & mood logging", inFree: true, inPro: true)
                featureDivider
                featureRow("Beautiful calendar", inFree: true, inPro: true)
                featureDivider
                featureRow("Gentle reminders", inFree: true, inPro: true)
                featureDivider
                featureRow("CSV export", inFree: true, inPro: true)
                featureDivider
                featureRow("Advanced pattern insights", inFree: false, inPro: true)
                featureDivider
                featureRow("PDF cycle reports", inFree: false, inPro: true)
            }
        }
    }

    private var featureHeaderRow: some View {
        HStack {
            Spacer(minLength: 0)
            Text("Free")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.5)
                .frame(width: 56, alignment: .center)
            Text("Pro")
                .font(CaelynFont.caption.weight(.bold))
                .foregroundStyle(CaelynColor.primaryPlum)
                .tracking(0.5)
                .frame(width: 56, alignment: .center)
        }
        .padding(.bottom, CaelynSpacing.xs)
    }

    private var featureDivider: some View {
        Rectangle()
            .fill(CaelynColor.deepPlumText.opacity(0.06))
            .frame(height: 1)
    }

    private func featureRow(_ title: String, inFree: Bool, inPro: Bool) -> some View {
        HStack {
            Text(title)
                .font(CaelynFont.subheadline)
                .foregroundStyle(CaelynColor.deepPlumText)
                .lineLimit(2)
            Spacer(minLength: 6)
            featureCheck(included: inFree)
                .frame(width: 56, alignment: .center)
            featureCheck(included: inPro, accent: CaelynColor.primaryPlum)
                .frame(width: 56, alignment: .center)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func featureCheck(included: Bool, accent: Color = CaelynColor.successSage) -> some View {
        if included {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
        } else {
            Text("—")
                .font(CaelynFont.body)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.25))
        }
    }

    // MARK: - Tier cards

    private var tierCards: some View {
        HStack(spacing: CaelynSpacing.sm) {
            PaywallTierCard(
                kind: .monthly,
                displayPrice: monthlyDisplayPrice,
                strikethroughPrice: monthlyOriginalPrice,
                perMonthLabel: nil,
                badgeText: "$2 OFF",
                badgeBackground: CaelynColor.alertRose,
                isSelected: selectedTier == .monthly,
                isBestValue: false
            ) {
                selectedTier = .monthly
            }

            PaywallTierCard(
                kind: .yearly,
                displayPrice: yearlyDisplayPrice,
                strikethroughPrice: nil,
                perMonthLabel: yearlyPerMonthLabel,
                badgeText: yearlySavingsBadgeText,
                badgeBackground: CaelynColor.successSage,
                isSelected: selectedTier == .yearly,
                isBestValue: true
            ) {
                selectedTier = .yearly
            }
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
                .opacity(isPurchasing ? 0.8 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || selectedProduct == nil)
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

    /// Subscription disclosure required by App Store Review for any
    /// auto-renewable IAP. Includes the auto-renew wording and the
    /// cancellation instruction. The actual subscription length and price are
    /// shown by the tier cards above so the user sees them in context.
    private var trustCopy: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Your core cycle data stays yours.")
                    .font(CaelynFont.footnote)
            }
            Text("Auto-renewable subscription. Renews at the price shown above unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in iOS Settings → Apple ID → Subscriptions.")
                .font(CaelynFont.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
        .multilineTextAlignment(.center)
        .padding(.top, CaelynSpacing.xs)
    }

    // MARK: - Empty / loading states

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
        case .monthly: return purchase.monthlyProduct
        case .yearly:  return purchase.yearlyProduct
        }
    }

    private var ctaTitle: String {
        if purchase.isPro { return "You're already Pro" }
        if isPurchasing { return "Subscribing…" }
        switch selectedTier {
        case .monthly: return "Continue with Monthly"
        case .yearly:  return "Continue with Yearly"
        }
    }

    /// All price-display computeds below are only rendered when
    /// `productsAreReady` is true (see body), so the nil branches are
    /// unreachable from the UI today. We still return neutral placeholders
    /// instead of guessed prices so a future refactor that drops the gate
    /// can never show stale or inaccurate marketing prices.
    private var monthlyDisplayPrice: String {
        guard let product = purchase.monthlyProduct else { return "—" }
        return "\(product.displayPrice)/mo"
    }

    /// Synthesized "was X" price for the discount badge — this is marketing copy,
    /// independent of StoreKit's real price. Derived from the live product price,
    /// so it stays consistent if pricing changes in App Store Connect.
    private var monthlyOriginalPrice: String? {
        guard let product = purchase.monthlyProduct else { return nil }
        let original = product.price + 2
        return formatPrice(original, with: product) + "/mo"
    }

    private var yearlyDisplayPrice: String {
        guard let product = purchase.yearlyProduct else { return "—" }
        return "\(product.displayPrice)/yr"
    }

    private var yearlyPerMonthLabel: String? {
        guard let product = purchase.yearlyProduct else { return nil }
        let perMonth = product.price / 12
        return "≈ \(formatPrice(perMonth, with: product))/mo"
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
        case .cancelled, .pending:
            break
        case .failed(let message):
            Haptics.warning()
            purchaseError = message
        }
    }

    private func runRestore() async {
        await purchase.restore()
        showRestoreNotice = true
    }
}

#Preview {
    PaywallView()
}
