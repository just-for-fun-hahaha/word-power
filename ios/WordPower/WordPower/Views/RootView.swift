import SwiftUI

struct RootView: View {
    @ObservedObject var appModel: AppModel

    @State private var isHomeButtonVisible = false
    @State private var homeButtonAutoHideTask: Task<Void, Never>?

    private let edgeRevealWidth: CGFloat = 28
    private let homeButtonRevealThreshold: CGFloat = 44
    private let homeButtonHeight: CGFloat = 44
    private let homeButtonAutoHideDelayNanoseconds: UInt64 = 2_500_000_000

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                screenBackground
                    .ignoresSafeArea()

                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(screenBackground)

                edgeRevealHandle

                if isHomeButtonVisible {
                    floatingHomeButton
                        .padding(.leading, 14)
                        .padding(.top, proxy.safeAreaInsets.top + 12)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isHomeButtonVisible)
        .overlay {
            if appModel.isLoading {
                ZStack {
                    Color.black.opacity(0.08).ignoresSafeArea()
                    ProgressView("Loading library...")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .alert("Something went wrong", isPresented: errorAlertBinding) {
            Button("OK") {
                appModel.lastErrorMessage = ""
            }
        } message: {
            Text(appModel.lastErrorMessage)
        }
        .sheet(item: wordActionBinding) { context in
            WordActionSheet(appModel: appModel, context: context)
        }
        .onChange(of: appModel.selectedSection) { _, newValue in
            if newValue == .home {
                hideHomeButton()
            }
        }
        .onDisappear {
            homeButtonAutoHideTask?.cancel()
            homeButtonAutoHideTask = nil
        }
    }

    private var isReaderMode: Bool {
        appModel.selectedSection == .reader
    }

    private var screenBackground: some View {
        Group {
            if isReaderMode {
                AppTheme.readerBackground
            } else {
                AppTheme.workspaceBackground
            }
        }
    }

    private var edgeRevealHandle: some View {
        Color.clear
            .frame(width: edgeRevealWidth)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(homeRevealGesture)
    }

    private var floatingHomeButton: some View {
        Button(action: showHome) {
            Label("Home", systemImage: "house.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .frame(height: homeButtonHeight)
                .background(Color.white.opacity(0.78), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: AppTheme.overlayShadow, radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to Home")
        .help("Go to Home")
    }

    private var homeRevealGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                guard appModel.selectedSection != .home else { return }
                guard value.startLocation.x <= edgeRevealWidth else { return }
                guard value.translation.width >= homeButtonRevealThreshold else { return }
                guard abs(value.translation.height) < 80 else { return }
                revealHomeButton()
            }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch appModel.selectedSection {
        case .home:
            HomeView(appModel: appModel)
        case .library:
            LibraryView(appModel: appModel)
        case .player:
            PlayerView(appModel: appModel)
        case .reader:
            ReaderView(appModel: appModel)
        case .vocabulary:
            VocabularyView(appModel: appModel)
        case .familiarity:
            FamiliarityView(appModel: appModel)
        case .statistics:
            StatisticsView(appModel: appModel)
        case .settings:
            SettingsView(appModel: appModel)
        }
    }

    private func showHome() {
        appModel.selectedSection = .home
        hideHomeButton()
    }

    private func revealHomeButton() {
        withAnimation {
            isHomeButtonVisible = true
        }
        scheduleHomeButtonAutoHide()
    }

    private func hideHomeButton() {
        homeButtonAutoHideTask?.cancel()
        homeButtonAutoHideTask = nil
        withAnimation {
            isHomeButtonVisible = false
        }
    }

    private func scheduleHomeButtonAutoHide() {
        homeButtonAutoHideTask?.cancel()
        homeButtonAutoHideTask = Task {
            try? await Task.sleep(nanoseconds: homeButtonAutoHideDelayNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation {
                    isHomeButtonVisible = false
                }
                homeButtonAutoHideTask = nil
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { !appModel.lastErrorMessage.isEmpty },
            set: { isPresented in
                if !isPresented {
                    appModel.lastErrorMessage = ""
                }
            }
        )
    }

    private var wordActionBinding: Binding<WordActionContext?> {
        Binding(
            get: { appModel.wordActionContext },
            set: { newValue in
                appModel.wordActionContext = newValue
            }
        )
    }
}
