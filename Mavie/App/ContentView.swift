import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Mavie")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            Text("Phase 0 · Project Bootstrap")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
