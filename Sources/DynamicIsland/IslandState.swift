import SwiftUI
import Combine

enum ExpandedContent {
    case music
    case timer
    case timerDone
}

enum IslandMode: Equatable {
    case compact
    case expanded(ExpandedContent)

    static func == (lhs: IslandMode, rhs: IslandMode) -> Bool {
        switch (lhs, rhs) {
        case (.compact, .compact): return true
        case (.expanded(let a), .expanded(let b)):
            switch (a, b) {
            case (.music, .music), (.timer, .timer), (.timerDone, .timerDone): return true
            default: return false
            }
        default: return false
        }
    }
}

struct IslandMetrics {
    static let compactIdle = CGSize(width: 200, height: 36)
    static let compactMusic = CGSize(width: 264, height: 36)
    static let compactTimer = CGSize(width: 240, height: 36)
    static let compactBoth = CGSize(width: 344, height: 36)
    static let expandedMusic = CGSize(width: 388, height: 176)
    static let expandedTimer = CGSize(width: 320, height: 208)
    static let expandedTimerDone = CGSize(width: 320, height: 168)
}

final class IslandState: ObservableObject {
    @Published var mode: IslandMode = .compact

    /// Hardware notch geometry of the screen the island sits on (0 = no notch).
    /// Set by the window controller from NSScreen's auxiliary top areas.
    var notchWidth: CGFloat = 0
    var notchHeight: CGFloat = 0

    var hasNotch: Bool { notchWidth > 0 }
    var compactPillHeight: CGFloat { hasNotch ? max(36, notchHeight) : 36 }

    let music = MusicMonitor()
    let timer = TimerManager()

    var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Called by the window controller whenever the island needs a new window size.
    var onResize: ((CGSize) -> Void)?

    private var cancellables = Set<AnyCancellable>()

    init() {
        timer.onFinish = { [weak self] in
            self?.expand(.timerDone)
        }
        // Any activity change re-fits the compact window.
        Publishers.CombineLatest(music.$active, timer.$phase)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.mode == .compact else { return }
                self.onResize?(self.currentSize)
            }
            .store(in: &cancellables)
    }

    var currentSize: CGSize {
        switch mode {
        case .compact:
            if hasNotch {
                // The pill spans the physical notch so the cutout disappears
                // into the black, with content flanking it - the iPhone trick.
                let side: CGFloat = music.active ? 68 : (timer.isLive ? 58 : 0)
                var width = notchWidth + 2 * side
                if music.active && timer.isLive { width += 80 } // timer bubble
                return CGSize(width: width, height: compactPillHeight)
            }
            if music.active && timer.isLive { return IslandMetrics.compactBoth }
            if music.active { return IslandMetrics.compactMusic }
            if timer.isLive { return IslandMetrics.compactTimer }
            return IslandMetrics.compactIdle
        case .expanded(let content):
            switch content {
            case .music: return IslandMetrics.expandedMusic
            case .timer: return IslandMetrics.expandedTimer
            case .timerDone: return IslandMetrics.expandedTimerDone
            }
        }
    }

    func expand(_ content: ExpandedContent) {
        mode = .expanded(content)
        onResize?(currentSize)
    }

    func collapse() {
        mode = .compact
        onResize?(currentSize)
    }
}
