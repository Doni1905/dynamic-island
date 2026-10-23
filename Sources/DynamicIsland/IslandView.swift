import SwiftUI
import AppKit

// MARK: - Root

struct IslandRootView: View {
    @EnvironmentObject var state: IslandState

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .compact:
            CompactIslandView()
        case .expanded(let expanded):
            switch expanded {
            case .music: ExpandedMusicView()
            case .timer: ExpandedTimerView()
            case .timerDone: TimerDoneView()
            }
        }
    }
}

// MARK: - Shared pieces

struct IslandCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// iPhone-style live audio waveform shown in the compact island.
struct LiveWaveform: View {
    let playing: Bool
    @State private var animating = false

    private let baseHeights: [CGFloat] = [5, 11, 8, 13, 6]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(baseHeights.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 14)
        .onAppear { animating = playing }
        .onChange(of: playing) { newValue in animating = newValue }
        .animation(
            playing ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true) : .default,
            value: animating
        )
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard playing, animating else { return baseHeights[index] * 0.55 }
        return baseHeights[index]
    }
}

// MARK: - Compact

struct CompactIslandView: View {
    @EnvironmentObject var state: IslandState
    @EnvironmentObject var music: MusicMonitor
    @EnvironmentObject var timer: TimerManager

    var body: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            pill
            if music.active && timer.isLive {
                timerBubble
            }
            Spacer(minLength: 0)
        }
        .frame(height: IslandMetrics.compactIdle.height)
    }

    @ViewBuilder
    private var pill: some View {
        if music.active {
            Button { state.expand(.music) } label: {
                HStack {
                    artworkView(size: 24)
                    Spacer()
                    LiveWaveform(playing: music.isPlaying)
                }
                .padding(.horizontal, 7)
                .frame(width: IslandMetrics.compactMusic.width, height: 36)
                .background(Color.black)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        } else if timer.isLive {
            Button { state.expand(.timer) } label: {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    Spacer()
                    Text(timer.remainingText)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .frame(width: IslandMetrics.compactTimer.width, height: 36)
                .background(Color.black)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        } else {
            Button { state.expand(.timer) } label: {
                Color.black
                    .frame(width: IslandMetrics.compactIdle.width, height: 36)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var timerBubble: some View {
        Button { state.expand(.timer) } label: {
            HStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                Text(timer.remainingText)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.black)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func artworkView(size: CGFloat) -> some View {
        Group {
            if let artwork = music.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(white: 0.18)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.45))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

// MARK: - Expanded: Music

struct ExpandedMusicView: View {
    @EnvironmentObject var state: IslandState
    @EnvironmentObject var music: MusicMonitor

    var body: some View {
        IslandCard {
            VStack(spacing: 10) {
                HStack {
                    Text(music.source == .spotify ? "Spotify" : "Music")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                    Button { music.openSourceApp() } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    artwork
                    VStack(alignment: .leading, spacing: 3) {
                        Text(music.trackTitle.isEmpty ? "Unknown track" : music.trackTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(music.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        transport
                    }
                    Spacer(minLength: 0)
                }

                progress
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(width: IslandMetrics.expandedMusic.width, height: IslandMetrics.expandedMusic.height)
        }
    }

    private var artwork: some View {
        Group {
            if let artwork = music.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(white: 0.18)
                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 62, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var transport: some View {
        HStack(spacing: 22) {
            Button { music.previousTrack() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            Button { music.togglePlayPause() } label: {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 19))
            }
            .buttonStyle(.plain)
            Button { music.nextTrack() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(.white)
    }

    private var progress: some View {
        let fraction = music.duration > 0 ? min(max(music.position / music.duration, 0), 1) : 0
        return HStack(spacing: 8) {
            Text(formatTime(music.position))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 4)
            Text(formatTime(music.duration))
        }
        .font(.system(size: 10).monospacedDigit())
        .foregroundColor(.white.opacity(0.55))
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Expanded: Timer

struct ExpandedTimerView: View {
    @EnvironmentObject var state: IslandState
    @EnvironmentObject var timer: TimerManager

    private let presets = [1, 5, 10, 25]

    var body: some View {
        IslandCard {
            VStack(spacing: 14) {
                header
                if timer.isLive {
                    runningBody
                } else {
                    presetsBody
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(width: IslandMetrics.expandedTimer.width, height: IslandMetrics.expandedTimer.height)
        }
    }

    private var header: some View {
        HStack {
            Label("Timer", systemImage: "timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
            Spacer()
        }
    }

    private var presetsBody: some View {
        VStack(spacing: 12) {
            Text("Start a timer")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
            HStack(spacing: 10) {
                ForEach(presets, id: \.self) { minutes in
                    Button { timer.start(minutes: minutes) } label: {
                        Text("\(minutes) min")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 58, height: 34)
                            .background(Color(white: 0.18))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var runningBody: some View {
        VStack(spacing: 12) {
            Text(timer.remainingText)
                .font(.system(size: 40, weight: .semibold).monospacedDigit())
                .foregroundColor(.white)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * timer.progress)
                }
            }
            .frame(height: 5)
            HStack(spacing: 12) {
                Button {
                    timer.phase == .running ? timer.pause() : timer.resume()
                } label: {
                    Label(timer.phase == .running ? "Pause" : "Resume",
                          systemImage: timer.phase == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 108, height: 34)
                        .background(Color(white: 0.18))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    timer.cancel()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 96, height: 34)
                        .background(Color(white: 0.18))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Expanded: Timer done

struct TimerDoneView: View {
    @EnvironmentObject var state: IslandState
    @EnvironmentObject var timer: TimerManager

    var body: some View {
        IslandCard {
            VStack(spacing: 12) {
                Label("Timer done", systemImage: "timer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                HStack(spacing: 12) {
                    Button {
                        timer.dismissDone()
                        state.collapse()
                    } label: {
                        Text("Done")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 96, height: 34)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        timer.repeatLast()
                        state.expand(.timer)
                    } label: {
                        Text("Repeat")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 96, height: 34)
                            .background(Color(white: 0.18))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(width: IslandMetrics.expandedTimerDone.width, height: IslandMetrics.expandedTimerDone.height)
        }
    }
}
