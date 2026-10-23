import AppKit

enum TimerPhase: Equatable {
    case idle
    case running
    case paused
    case done
}

/// Live countdown shown in the island, like an iPhone timer Live Activity.
final class TimerManager: ObservableObject {
    @Published private(set) var phase: TimerPhase = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0

    var onFinish: (() -> Void)?

    private var tick: Foundation.Timer?
    private var endDate: Date?

    var isLive: Bool { phase == .running || phase == .paused }

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(1 - remaining / total, 0), 1)
    }

    var remainingText: String {
        let seconds = Int(remaining.rounded(.up))
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    func start(minutes: Int) {
        total = TimeInterval(minutes * 60)
        remaining = total
        endDate = Date().addingTimeInterval(total)
        phase = .running
        startTicking()
    }

    func pause() {
        guard phase == .running else { return }
        tick?.invalidate()
        tick = nil
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        endDate = Date().addingTimeInterval(remaining)
        phase = .running
        startTicking()
    }

    func cancel() {
        tick?.invalidate()
        tick = nil
        phase = .idle
        remaining = 0
        total = 0
        endDate = nil
    }

    func repeatLast() {
        guard total > 0 else { return }
        remaining = total
        endDate = Date().addingTimeInterval(total)
        phase = .running
        startTicking()
    }

    func dismissDone() {
        guard phase == .done else { return }
        cancel()
    }

    private func startTicking() {
        tick?.invalidate()
        let timer = Foundation.Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateRemaining()
        }
        RunLoop.main.add(timer, forMode: .common)
        tick = timer
    }

    private func updateRemaining() {
        guard phase == .running, let endDate = endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            tick?.invalidate()
            tick = nil
            remaining = 0
            phase = .done
            NSSound(named: NSSound.Name("Glass"))?.play()
            onFinish?()
        } else {
            remaining = left
        }
    }
}
