# Dynamic Island for Mac

A faithful replica of the iPhone Dynamic Island, rebuilt as a native macOS app.
A black pill lives at the top center of your screen and shows live activities,
exactly like the iPhone: compact when something runs, a separate minimal bubble
when two things run at once, and an expanded panel when you tap it.

## Sample scope (v0.1.0)

This first build covers the two activities approved for the sample:

- **Music** - Apple Music and Spotify. Compact: artwork + live waveform.
  Expanded: artwork, title, artist, progress with times, previous /
  play-pause / next, and a button to open the source app.
- **Timer** - tap the idle island, pick 1, 5, 10 or 25 minutes. Live countdown
  in the pill (orange, like iPhone), pause / resume / cancel in the expanded
  panel, sound and auto-expanded "Timer done" panel with Done / Repeat.
- Music + timer together: timer splits into its own minimal bubble beside the
  music pill, like two Live Activities on iPhone.

Interactions: click an activity to expand it, click anywhere outside the
island to collapse. The grow / shrink animation follows the iPhone's springy
feel and honours macOS Reduce Motion.

## Build and run

```sh
git pull          # after cloning: skip this
./build_app.sh
open build/DynamicIsland.app
```

Requirements: macOS 13 or later with the Swift toolchain (Xcode or Command
Line Tools). The app is unsigned; on first run allow it in
System Settings > Privacy & Security if Gatekeeper asks.

The first time music plays, macOS asks for permission to control Music /
Spotify (one-time Automation prompt). Without it the music activity stays
empty; the timer works regardless.

## Honest limits

- Browser / YouTube and other apps' audio cannot be read without private APIs;
  only Apple Music and Spotify are covered.
- It does not capture other apps' notifications.
- Built for a free workflow: no accounts, no paid services, no analytics.
