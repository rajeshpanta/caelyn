import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @State private var vm = OnboardingViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack(alignment: .top) {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                progressArea
                    .frame(height: 36)
                    .padding(.horizontal, MavieSpacing.lg)
                    .padding(.top, MavieSpacing.md)

                stepContent
                    .id(vm.step)
                    .transition(stepTransition)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: vm.step)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case .welcome:
            WelcomeStep(vm: vm)
        case .privacy:
            PrivacyStep(vm: vm)
        case .lastPeriod:
            LastPeriodStep(vm: vm)
        case .cycleLength:
            CycleLengthStep(vm: vm)
        case .periodLength:
            PeriodLengthStep(vm: vm)
        case .goals:
            GoalsStep(vm: vm)
        case .reminders:
            RemindersStep(vm: vm)
        case .lock:
            LockStep(vm: vm)
        case .done:
            DoneStep(vm: vm) {
                vm.complete(in: modelContext)
            }
        }
    }

    @ViewBuilder
    private var progressArea: some View {
        if vm.step.showsProgressBar {
            OnboardingProgress(
                position: vm.step.surveyPosition ?? 0,
                total: vm.step.surveyTotal,
                onBack: { vm.back() }
            )
        } else {
            Color.clear
        }
    }

    private var stepTransition: AnyTransition {
        let inEdge: Edge = vm.navigationDirection == .forward ? .trailing : .leading
        let outEdge: Edge = vm.navigationDirection == .forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: inEdge).combined(with: .opacity),
            removal: .move(edge: outEdge).combined(with: .opacity)
        )
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                MavieColor.backgroundCream,
                MavieColor.blush.opacity(0.55)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    OnboardingFlow()
        .modelContainer(Persistence.preview)
}
