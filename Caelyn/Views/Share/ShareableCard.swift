import SwiftUI

/// A beautiful, on-device-rendered card the user can CHOOSE to share (Messages,
/// Instagram story, Save to Photos, AirDrop). This is Caelyn's only "growth"
/// surface, and it is privacy-safe by design: only the rendered IMAGE ever
/// leaves the phone — never her cycle data. Templates use warm, non-clinical
/// language (a vibe, a milestone, a value) — never exact dates or medical numbers.
enum ShareableMoment: Equatable {
    case oneWeek
    case learnedRhythm
    case phase(name: String, vibe: String)
    case privacy

    var eyebrow: String {
        switch self {
        case .oneWeek:       return "A LITTLE MILESTONE"
        case .learnedRhythm: return "MY BODY, UNDERSTOOD"
        case .phase:         return "WHERE I AM TODAY"
        case .privacy:       return "WHY I LOVE IT"
        }
    }

    var headline: String {
        switch self {
        case .oneWeek:            return "One week of\nlistening to myself"
        case .learnedRhythm:      return "Caelyn learned\nmy rhythm"
        case .phase(let name, _): return "\(name)\nphase"
        case .privacy:            return "My cycle stays\non my phone"
        }
    }

    var subline: String {
        switch self {
        case .oneWeek:            return "Small check-ins, big self-knowledge."
        case .learnedRhythm:      return "It knows my patterns — privately, just for me."
        case .phase(_, let vibe): return vibe
        case .privacy:            return "No account. No servers. No one but me."
        }
    }

    var symbol: String {
        switch self {
        case .oneWeek:       return "heart.circle.fill"
        case .learnedRhythm: return "sparkles"
        case .phase:         return "moon.stars.fill"
        case .privacy:       return "lock.fill"
        }
    }

    var accent: Color {
        switch self {
        case .oneWeek:       return CaelynColor.primaryPlum
        case .learnedRhythm: return CaelynColor.primaryPlum
        case .phase:         return CaelynColor.softRose
        case .privacy:       return CaelynColor.successSage
        }
    }
}

/// The card visual. Rendered at ~3x into an image; also shown as a live preview.
struct ShareableCardView: View {
    let moment: ShareableMoment

    var body: some View {
        ZStack {
            // Soft branded gradient.
            LinearGradient(
                colors: [CaelynColor.backgroundCream, moment.accent.opacity(0.28), CaelynColor.lavender.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // The signature ring motif, oversized + faint, as a watermark.
            ringMotif
                .frame(width: 280, height: 280)
                .opacity(0.5)
                .offset(x: 90, y: -150)

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: moment.symbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(moment.accent)

                Spacer(minLength: 0)

                Text(moment.eyebrow)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(moment.accent.opacity(0.9))
                    .padding(.bottom, 10)

                Text(moment.headline)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(moment.subline)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                // Wordmark + privacy tagline — the word-of-mouth hook.
                HStack(spacing: 7) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CaelynColor.primaryPlum)
                    Text("Caelyn")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(CaelynColor.primaryPlum)
                    Text("· period tracking that never leaves your phone")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(34)
        }
    }

    /// A decorative echo of CycleRingView (rose / sage / lavender arcs).
    private var ringMotif: some View {
        ZStack {
            Circle().stroke(CaelynColor.warmSand.opacity(0.5), lineWidth: 22)
            Circle().trim(from: 0, to: 0.18)
                .stroke(CaelynColor.softRose, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().trim(from: 0.42, to: 0.5)
                .stroke(CaelynColor.sage, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().trim(from: 0.8, to: 1.0)
                .stroke(CaelynColor.lavender, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Presents the card with a live preview and a Share button. Renders the image
/// on-device; the ShareLink hands the system share sheet ONLY that image.
struct ShareCardSheet: View {
    let moment: ShareableMoment
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: CaelynSpacing.lg) {
                ShareableCardView(moment: moment)
                    .frame(width: 288, height: 456)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(CaelynColor.deepPlumText.opacity(0.06), lineWidth: 1)
                    )
                    .caelynShadow(.card)
                    .padding(.top, CaelynSpacing.md)

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Only this image is shared — never your cycle data.")
                }
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))

                if let rendered {
                    ShareLink(
                        item: rendered,
                        preview: SharePreview("A moment from Caelyn", image: rendered)
                    ) {
                        Label("Share this card", systemImage: "square.and.arrow.up")
                            .font(CaelynFont.body.weight(.semibold))
                            .foregroundStyle(CaelynColor.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(CaelynColor.primaryPlum, in: Capsule())
                    }
                    .padding(.horizontal, CaelynSpacing.lg)
                } else {
                    ProgressView().padding(.vertical, 14)
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, CaelynSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Share a moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { rendered = renderCard() }
        }
    }

    @MainActor
    private func renderCard() -> Image? {
        let renderer = ImageRenderer(content:
            ShareableCardView(moment: moment).frame(width: 900, height: 1425)
        )
        renderer.scale = 3
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}

#Preview {
    ShareCardSheet(moment: .learnedRhythm)
}
