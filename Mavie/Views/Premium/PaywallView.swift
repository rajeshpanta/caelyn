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
                    VStack(spacing: MavieSpacing.lg) {
                        hero
                        titleBlock
                        featureSection
                        tierCards
                        ctaButton
                        footerLinks
                        trustCopy
                    }
                    .padding(MavieSpacing.lg)
                    .padding(.top, MavieSpacing.sm)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.35))
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
                 ? "You're all set with Mavie Pro."
                 : "No active Mavie Pro subscription was found on this Apple ID.")
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                MavieColor.backgroundCream,
                MavieColor.lavender.opacity(0.35),
                MavieColor.blush.opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            Circle().fill(MavieColor.lavender).frame(width: 160, height: 160).offset(x: -44, y: -16)
            Circle().fill(MavieColor.softRose.opacity(0.85)).frame(width: 140, height: 140).offset(x: 50, y: 16)
            Circle().fill(MavieColor.sage.opacity(0.55)).frame(width: 100, height: 100).offset(x: -8, y: 60)
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(MavieColor.primaryPlum.opacity(0.85))
                .offset(y: -8)
        }
        .frame(height: 200)
        .padding(.top, MavieSpacing.sm)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Unlock Mavie Pro")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(MavieColor.deepPlumText)
                .multilineTextAlignment(.center)
            Text("Understand your body, deeper. With insights, reports, and reminders that grow with you.")
                .font(MavieFont.body)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MavieSpacing.sm)
        }
    }

    // MARK: - Features

    private var featureSection: some View {
        MavieCard(padding: MavieSpacing.md) {
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
                featureRow("Apple Health sync", inFree: true, inPro: true)
                featureDivider
                featureRow("Gentle reminders", inFree: true, inPro: true)
                featureDivider
                featureRow("Advanced pattern insights", inFree: false, inPro: true)
                featureDivider
                featureRow("PDF cycle reports", inFree: false, inPro: true)
                featureDivider
                featureRow("Custom themes", inFree: false, inPro: true)
                featureDivider
                featureRow("Yearly summary", inFree: false, inPro: true)
            }
        }
    }

    private var featureHeaderRow: some View {
        HStack {
            Spacer(minLength: 0)
            Text("Free")
                .font(MavieFont.caption.weight(.semibold))
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                .tracking(0.5)
                .frame(width: 56, alignment: .center)
            Text("Pro")
                .font(MavieFont.caption.weight(.bold))
                .foregroundStyle(MavieColor.primaryPlum)
                .tracking(0.5)
                .frame(width: 56, alignment: .center)
        }
        .padding(.bottom, MavieSpacing.xs)
    }

    private var featureDivider: some View {
        Rectangle()
            .fill(MavieColor.deepPlumText.opacity(0.06))
            .frame(height: 1)
    }

    private func featureRow(_ title: String, inFree: Bool, inPro: Bool) -> some View {
        HStack {
            Text(title)
                .font(MavieFont.subheadline)
                .foregroundStyle(MavieColor.deepPlumText)
                .lineLimit(2)
            Spacer(minLength: 6)
            featureCheck(included: inFree)
                .frame(width: 56, alignment: .center)
            featureCheck(included: inPro, accent: MavieColor.primaryPlum)
                .frame(width: 56, alignment: .center)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func featureCheck(included: Bool, accent: Color = MavieColor.successSage) -> some View {
        if included {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
        } else {
            Text("—")
                .font(MavieFont.body)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.25))
        }
    }

    // MARK: - Tier cards

    private var tierCards: some View {
        HStack(spacing: MavieSpacing.sm) {
            PaywallTierCard(
                kind: .monthly,
                displayPrice: monthlyDisplayPrice,
                strikethroughPrice: monthlyOriginalPrice,
                perMonthLabel: nil,
                badgeText: "$2 OFF",
                badgeBackground: MavieColor.alertRose,
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
                badgeBackground: MavieColor.successSage,
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
                        .font(MavieFont.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, MavieSpacing.md)
                .padding(.horizontal, MavieSpacing.lg)
                .foregroundStyle(.white)
                .background(MavieColor.primaryPlum, in: RoundedRectangle(cornerRadius: MavieRadius.button, style: .continuous))
                .opacity(isPurchasing ? 0.8 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || selectedProduct == nil)
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: MavieSpacing.lg) {
            Button("Restore purchases") { Task { await runRestore() } }
                .font(MavieFont.subheadline.weight(.medium))
                .foregroundStyle(MavieColor.primaryPlum)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var trustCopy: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Your core cycle data stays yours.")
                    .font(MavieFont.footnote)
            }
            Text("Cancel anytime in iOS Settings → Subscriptions.")
                .font(MavieFont.footnote)
        }
        .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
        .multilineTextAlignment(.center)
        .padding(.top, MavieSpacing.xs)
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

    private var monthlyDisplayPrice: String {
        if let product = purchase.monthlyProduct {
            return "\(product.displayPrice)/mo"
        }
        return "$3.99/mo"
    }

    /// Synthesized "was X" price for the discount badge — this is marketing copy,
    /// independent of StoreKit's real price.
    private var monthlyOriginalPrice: String {
        guard let product = purchase.monthlyProduct else { return "$5.99" }
        let original = product.price + 2
        return formatPrice(original, with: product) + "/mo"
    }

    private var yearlyDisplayPrice: String {
        if let product = purchase.yearlyProduct {
            return "\(product.displayPrice)/yr"
        }
        return "$19.99/yr"
    }

    private var yearlyPerMonthLabel: String? {
        guard let product = purchase.yearlyProduct else { return "≈ $1.67/mo" }
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
