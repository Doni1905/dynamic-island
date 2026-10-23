import AppKit

/// Watches Apple Music and Spotify through AppleScript and publishes the
/// current "now playing" state for the island's music activity.
final class MusicMonitor: ObservableObject {
    enum SourceApp: String {
        case music = "Music"
        case spotify = "Spotify"

        var bundleID: String {
            switch self {
            case .music: return "com.apple.Music"
            case .spotify: return "com.spotify.client"
            }
        }
    }

    @Published private(set) var active = false
    @Published private(set) var isPlaying = false
    @Published private(set) var trackTitle = ""
    @Published private(set) var artist = ""
    @Published private(set) var album = ""
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var artwork: NSImage?
    @Published private(set) var source: SourceApp = .music

    private var pollTimer: Foundation.Timer?
    private var artworkKey = ""

    init() {
        pollTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    deinit { pollTimer?.invalidate() }

    // MARK: - Polling

    private func isRunning(_ app: SourceApp) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty == false
    }

    private struct Snapshot {
        var playing: Bool
        var title: String
        var artist: String
        var album: String
        var position: Double
        var duration: Double
    }

    private func poll() {
        // AppleScript calls can block briefly; keep them off the main thread.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.pollOnBackground()
        }
    }

    private func pollOnBackground() {
        // Prefer whichever app is actually playing; otherwise keep the last source.
        var chosen: SourceApp?
        var snapshot: Snapshot?
        for app in [source, SourceApp.music, SourceApp.spotify] {
            guard isRunning(app), let snap = query(app), snap.playing else { continue }
            chosen = app
            snapshot = snap
            break
        }
        if chosen == nil {
            for app in [source, SourceApp.music, SourceApp.spotify] {
                guard isRunning(app), let snap = query(app) else { continue }
                chosen = app
                snapshot = snap
                break
            }
        }

        DispatchQueue.main.async {
            if let app = chosen, let snap = snapshot {
                let changedTrack = snap.title != self.trackTitle || app != self.source
                self.source = app
                self.active = true
                self.isPlaying = snap.playing
                self.trackTitle = snap.title
                self.artist = snap.artist
                self.album = snap.album
                self.position = snap.position
                self.duration = snap.duration
                if changedTrack { self.loadArtwork(for: app, track: snap.title) }
            } else {
                self.active = false
                self.isPlaying = false
                self.artwork = nil
                self.artworkKey = ""
            }
        }
    }

    private func query(_ app: SourceApp) -> Snapshot? {
        let scriptText: String
        switch app {
        case .music:
            scriptText = """
            tell application "Music"
                if player state is stopped then error "stopped"
                set s to player state as string
                set t to name of current track
                set a to artist of current track
                set al to album of current track
                set p to player position
                set d to duration of current track
                return {s, t, a, al, p, d}
            end tell
            """
        case .spotify:
            scriptText = """
            tell application "Spotify"
                set s to player state as string
                set t to name of current track
                set a to artist of current track
                set al to album of current track
                set p to player position
                set d to (duration of current track) / 1000
                return {s, t, a, al, p, d}
            end tell
            """
        }
        guard let script = NSAppleScript(source: scriptText) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        guard let state = result.atIndex(1)?.stringValue else { return nil }
        return Snapshot(
            playing: state == "playing",
            title: result.atIndex(2)?.stringValue ?? "",
            artist: result.atIndex(3)?.stringValue ?? "",
            album: result.atIndex(4)?.stringValue ?? "",
            position: result.atIndex(5)?.doubleValue ?? 0,
            duration: result.atIndex(6)?.doubleValue ?? 0
        )
    }

    // MARK: - Artwork

    private func loadArtwork(for app: SourceApp, track: String) {
        let key = "\(app.rawValue)|\(track)"
        guard key != artworkKey else { return }
        artworkKey = key
        switch app {
        case .music:
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let scriptText = """
                tell application "Music"
                    try
                        return data of artwork 1 of current track
                    on error
                        return ""
                    end try
                end tell
                """
                guard let script = NSAppleScript(source: scriptText) else { return }
                var error: NSDictionary?
                let result = script.executeAndReturnError(&error)
                var image: NSImage?
                if error == nil {
                    let data = result.data.isEmpty ? (result.atIndex(1)?.data ?? Data()) : result.data
                    if !data.isEmpty { image = NSImage(data: data) }
                }
                DispatchQueue.main.async { self?.artwork = image }
            }
        case .spotify:
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let scriptText = """
                tell application "Spotify"
                    try
                        return artwork url of current track
                    on error
                        return ""
                    end try
                end tell
                """
                guard let script = NSAppleScript(source: scriptText) else { return }
                var error: NSDictionary?
                let result = script.executeAndReturnError(&error)
                guard error == nil, let urlString = result.stringValue, !urlString.isEmpty,
                      let url = URL(string: urlString),
                      let data = try? Data(contentsOf: url) else {
                    DispatchQueue.main.async { self?.artwork = nil }
                    return
                }
                let image = NSImage(data: data)
                DispatchQueue.main.async { self?.artwork = image }
            }
        }
    }

    // MARK: - Controls

    private func run(_ scriptText: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let script = NSAppleScript(source: scriptText) else { return }
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }

    func togglePlayPause() { run("tell application \"\(source.rawValue)\" to playpause") }
    func nextTrack() { run("tell application \"\(source.rawValue)\" to next track") }
    func previousTrack() { run("tell application \"\(source.rawValue)\" to previous track") }

    func openSourceApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
