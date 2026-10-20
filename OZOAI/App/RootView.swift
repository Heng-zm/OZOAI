import Foundation
import SwiftUI

struct RootView: View {
    @StateObject private var store = ChatStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var speech = SpeechRecognizer()

    @AppStorage("ozo.onboardingDismissed") private var onboardingDismissed = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSidebar = false
    @State private var showSettings = false
    @State private var showModelPicker = false
    @State private var showOnboarding = false
    @State private var didCheckOnboarding = false

    private var currentModelID: String {
        store.selectedModelID ?? settings.defaultModelID
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                ChatView(
                    speech: speech,
                    onOpenSidebar: openSidebar,
                    onOpenSettings: openSettings,
                    onOpenModelPicker: { showModelPicker = true }
                )
                .environmentObject(store)
                .environmentObject(settings)
                .disabled(showSidebar)

                if showSidebar {
                    Color.black.opacity(0.26)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            closeSidebar()
                        }

                    SidebarView(
                        topInset: geometry.safeAreaInsets.top,
                        bottomInset: geometry.safeAreaInsets.bottom,
                        onClose: closeSidebar,
                        onOpenSettings: openSettings
                    )
                    .environmentObject(store)
                    .environmentObject(settings)
                    .frame(width: min(geometry.size.width * 0.86, 352))
                    .frame(maxHeight: .infinity)
                    .background(.regularMaterial)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 28,
                            topTrailingRadius: 28,
                            style: .continuous
                        )
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 30, x: 12, y: 0)
                    .ignoresSafeArea()
                    .transition(.move(edge: .leading))
                    .zIndex(1)
                }
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: showSidebar)
        }
        .tint(OZOTheme.accent)
        .preferredColorScheme(settings.appearance.colorScheme)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(store)
        }
        .sheet(isPresented: $showModelPicker) {
            ModelPickerView(selectedID: currentModelID) { model in
                apply(model)
            }
            .environmentObject(settings)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(settings)
        }
        .onAppear {
            presentOnboardingIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                speech.stop()
                settings.savePreferences()
            }
            if phase == .background {
                store.flushPersistence()
            }
        }
    }

    // MARK: - Actions

    private func openSidebar() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            showSidebar = true
        }
    }

    private func closeSidebar() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            showSidebar = false
        }
    }

    private func openSettings() {
        if showSidebar {
            withAnimation(.easeOut(duration: 0.2)) {
                showSidebar = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showSettings = true
            }
        } else {
            showSettings = true
        }
    }

    private func apply(_ model: AIModel) {
        if let conversationID = store.currentID {
            store.setModel(model.id, for: conversationID)
        }
        settings.setDefaultModel(model.id)
    }

    private func presentOnboardingIfNeeded() {
        guard !didCheckOnboarding else { return }
        didCheckOnboarding = true

        guard !settings.hasAPIKey, !onboardingDismissed else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            showOnboarding = true
        }
    }
}
