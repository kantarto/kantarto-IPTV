import SwiftUI
import AVKit
import Combine
import AppKit

/// Wraps AVKit's AVPlayerView directly (instead of SwiftUI's VideoPlayer) because
/// SwiftUI.VideoPlayer crashes on this OS build inside the private _AVKit_SwiftUI
/// framework (generic metadata resolution failure for AVPlayerView).
private struct AVPlayerContainerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .default
        view.showsFullScreenToggleButton = true
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

struct PlayerView: View {
    let title: String?
    let url: URL?
    /// Only live channels retry-on-failure: a live stream can drop and recover.
    /// A movie/series that fails to open almost always means an unsupported
    /// container (e.g. MKV) — retrying the same file just repeats the same
    /// failure, so those hand off to VLC right away instead of waiting through
    /// several retries first.
    var isLive: Bool = true

    @State private var player: AVPlayer?
    @State private var playbackError: String?
    @State private var vodState: VODState?
    @State private var countdown: Int = 5
    @State private var isExternalPlaybackActive = false
    @State private var isReconnecting = false
    @State private var retryCount = 0
    @State private var retryTask: Task<Void, Never>?
    @State private var countdownTask: Task<Void, Never>?
    @State private var cancellables: Set<AnyCancellable> = []
    /// Keeps the display awake while a channel/movie is actually playing —
    /// without this, watching a live match with no mouse/keyboard activity
    /// eventually lets the Mac's display sleep like normal.
    @State private var sleepAssertion: NSObjectProtocol?

    private enum VODState {
        case countingDown
        case openedInVLC
        case needsVLC
    }

    private var maxRetries: Int { isLive ? 3 : 0 }

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.05).ignoresSafeArea()

            mainArea

            // Live failures (after retries are exhausted) are a genuine, unresolved
            // problem, so this stays as an explicit error.
            if let playbackError {
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text(playbackError)
                            .font(.callout)
                            .foregroundStyle(.white)
                        if let debugPath {
                            Text(debugPath)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Button {
                            openExternally()
                        } label: {
                            Label(vlcInstalled ? "Άνοιγμα σε VLC" : "Λήψη VLC", systemImage: vlcInstalled ? "play.rectangle" : "arrow.down.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.white.opacity(0.25))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if isReconnecting {
                VStack {
                    Spacer()
                    Label("Επανασύνδεση…", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                }
            }

            if isExternalPlaybackActive {
                VStack {
                    HStack {
                        Spacer()
                        Label("AirPlay", systemImage: "airplayvideo")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding([.top, .trailing], 14)
                    }
                    Spacer()
                }
            }
        }
        .animation(.default, value: playbackError)
        .navigationTitle(title ?? "")
        .onAppear { setUpPlayer() }
        .onChange(of: url) { _, _ in setUpPlayer() }
        .onDisappear { endPreventingSleep() }
    }

    /// Exactly one of these replaces the whole video area at a time: the actual
    /// player, the idle placeholder, or — for a movie/series macOS can't open —
    /// a branded hand-off screen instead of AVKit's own "media unavailable" icon.
    @ViewBuilder
    private var mainArea: some View {
        switch vodState {
        case .countingDown:
            countdownView
        case .openedInVLC:
            handoffDoneView
        case .needsVLC:
            needsVLCView
        case nil:
            if let player {
                AVPlayerContainerView(player: player)
                    .onDisappear { player.pause() }
            } else {
                idlePlaceholder
            }
        }
    }

    private var idlePlaceholder: some View {
        VStack(spacing: 18) {
            ProfileAvatarView(diameter: 96, ringWidth: 2)
            VStack(spacing: 4) {
                Text("kantarto IPTV")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Επίλεξε κανάλι, ταινία ή επεισόδιο για αναπαραγωγή.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var countdownView: some View {
        VStack(spacing: 20) {
            ProfileAvatarView(diameter: 96, ringWidth: 2)
            VStack(spacing: 6) {
                Text("Άνοιγμα σε VLC")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Αυτό το περιεχόμενο παίζει καλύτερα εκεί.")
                    .foregroundStyle(.secondary)
            }
            Text("\(countdown)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: countdown)
                .frame(width: 60)
            Button("Άνοιγμα τώρα") { openNow() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private var handoffDoneView: some View {
        VStack(spacing: 18) {
            ProfileAvatarView(diameter: 96, ringWidth: 2)
            VStack(spacing: 4) {
                Text("Συνεχίζει στο VLC")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Αυτό το περιεχόμενο ανοίγει καλύτερα εκεί.")
                    .foregroundStyle(.secondary)
            }
            Button("Άνοιγμα ξανά") { openExternally() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private var needsVLCView: some View {
        VStack(spacing: 18) {
            ProfileAvatarView(diameter: 96, ringWidth: 2)
            VStack(spacing: 4) {
                Text("Χρειάζεται το VLC")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Αυτό το περιεχόμενο δεν παίζει με τον player του macOS.")
                    .foregroundStyle(.secondary)
            }
            Button("Λήψη VLC") { openExternally() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    /// Shows what was actually requested (kind + filename, no credentials) next to
    /// a playback error — useful to tell "wrong file extension" apart from
    /// "server rejected the connection" without exposing the account password.
    private var debugPath: String? {
        guard let url else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let kind = parts.first, let file = parts.last, parts.count >= 2 else { return nil }
        return "\(kind)/…/\(file)"
    }

    private var vlcInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.videolan.vlc") != nil
    }

    private func openExternally() {
        guard let url else { return }
        if let vlcURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.videolan.vlc") {
            NSWorkspace.shared.open([url], withApplicationAt: vlcURL, configuration: NSWorkspace.OpenConfiguration())
        } else if let downloadPage = URL(string: "https://www.videolan.org/vlc/") {
            NSWorkspace.shared.open(downloadPage)
        }
    }

    private func openNow() {
        countdownTask?.cancel()
        countdownTask = nil
        openExternally()
        vodState = .openedInVLC
    }

    private func beginPreventingSleep() {
        guard sleepAssertion == nil else { return }
        sleepAssertion = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled, .userInitiated],
            reason: "Αναπαραγωγή βίντεο"
        )
    }

    private func endPreventingSleep() {
        if let sleepAssertion {
            ProcessInfo.processInfo.endActivity(sleepAssertion)
        }
        sleepAssertion = nil
    }

    /// Full reset for a newly chosen channel/movie/episode — cancels any pending
    /// reconnect/countdown from whatever was playing before.
    private func setUpPlayer() {
        retryTask?.cancel()
        retryTask = nil
        countdownTask?.cancel()
        countdownTask = nil
        retryCount = 0
        isReconnecting = false
        playbackError = nil
        vodState = nil
        player?.pause()
        cancellables.removeAll()
        isExternalPlaybackActive = false
        endPreventingSleep()

        guard let url else {
            player = nil
            return
        }
        startPlayback(url: url)
    }

    private func startPlayback(url: URL) {
        let newPlayer = AVPlayer(url: url)
        newPlayer.allowsExternalPlayback = true
        player = newPlayer
        newPlayer.play()
        observe(newPlayer)
        beginPreventingSleep()
    }

    private func observe(_ avPlayer: AVPlayer) {
        avPlayer.publisher(for: \.isExternalPlaybackActive)
            .receive(on: DispatchQueue.main)
            .sink { isExternalPlaybackActive = $0 }
            .store(in: &cancellables)

        // Only `.failed` is a genuinely terminal state — the item cannot recover
        // on its own. Transient network blips (buffering, a dropped HLS segment)
        // show up as error-log entries or "failed to play to end time" without the
        // item actually dying, so those are intentionally ignored here — treating
        // them as fatal made the error banner pop up on every brief live-TV stutter.
        //
        // When the item genuinely fails, retry a few times with backoff (the
        // stream/network may just be flaky) before giving up and showing the error.
        avPlayer.publisher(for: \.currentItem?.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .readyToPlay:
                    retryCount = 0
                    isReconnecting = false
                case .failed:
                    handleFailure()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func handleFailure() {
        guard let url else { return }

        guard isLive else {
            player = nil // hide AVKit's own "media unavailable" placeholder
            endPreventingSleep()
            if vlcInstalled {
                startCountdown()
            } else {
                vodState = .needsVLC
            }
            return
        }

        guard retryCount < maxRetries else {
            isReconnecting = false
            playbackError = player?.currentItem?.error?.localizedDescription
                ?? "Η αναπαραγωγή απέτυχε."
            return
        }
        retryCount += 1
        isReconnecting = true
        cancellables.removeAll()
        let delaySeconds = Double(retryCount) * 2 // 2s, 4s, 6s
        retryTask = Task {
            try? await Task.sleep(for: .seconds(delaySeconds))
            guard !Task.isCancelled else { return }
            startPlayback(url: url)
        }
    }

    private func startCountdown() {
        countdown = 5
        vodState = .countingDown
        countdownTask?.cancel()
        countdownTask = Task {
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdown -= 1
            }
            guard !Task.isCancelled else { return }
            openExternally()
            vodState = .openedInVLC
        }
    }
}
