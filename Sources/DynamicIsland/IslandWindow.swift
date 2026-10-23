import AppKit
import SwiftUI

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class IslandWindowController: NSWindowController {
    let state = IslandState()
    private var globalClickMonitor: Any?
    private var screenObserver: NSObjectProtocol?

    init() {
        let panel = IslandPanel(
            contentRect: NSRect(origin: .zero, size: IslandMetrics.compactIdle),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusBarWindow)) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.hidesOnDeactivate = false

        let root = IslandRootView()
            .environmentObject(state)
            .environmentObject(state.music)
            .environmentObject(state.timer)
        panel.contentView = NSHostingView(rootView: root)

        super.init(window: panel)

        state.onResize = { [weak self] size in
            self?.resize(to: size, animated: !(self?.state.reduceMotion ?? false))
        }
        resize(to: state.currentSize, animated: false)

        // Click anywhere outside the island collapses it.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.state.mode != .compact else { return }
            self.state.collapse()
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.resize(to: self.state.currentSize, animated: false)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit {
        if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
        if let observer = screenObserver { NotificationCenter.default.removeObserver(observer) }
    }

    func resize(to size: CGSize, animated: Bool) {
        guard let window = window, let screen = window.screen ?? NSScreen.main else { return }
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        let rect = NSRect(origin: origin, size: size)
        guard rect != window.frame else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.38
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.32, 1.1, 0.42, 1.0)
                context.allowsImplicitAnimation = true
                window.animator().setFrame(rect, display: true)
            }
        } else {
            window.setFrame(rect, display: true)
        }
    }
}
