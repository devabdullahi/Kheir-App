import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var opacity: Double = 1.0

    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                Color(red: 0.118, green: 0.361, blue: 0.165)
                    .ignoresSafeArea()

                Image("kheir_loading_screen")
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }
            .accessibilityIdentifier("splashScreen")
            .opacity(opacity)
            .task {
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(.easeOut(duration: 0.4)) {
                    opacity = 0
                }
                try? await Task.sleep(for: .seconds(0.4))
                isActive = true
            }
        }
    }
}
