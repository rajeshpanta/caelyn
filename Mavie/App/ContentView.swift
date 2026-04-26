import SwiftUI

struct ContentView: View {
    var body: some View {
        ComponentGallery()
    }
}

#Preview {
    ContentView()
        .modelContainer(Persistence.preview)
}
