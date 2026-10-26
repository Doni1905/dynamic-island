# Notification-capture feasibility probe (read-only)

`island_probe.swift` checks whether this Mac lets an app *read* Notification Center banners
through the Accessibility API, and what shape they have. It does not move, hide or change any
banner or setting, writes no files, uses no network, and prints no notification text (only
roles, counts and text lengths).

```sh
git pull
swift tools/island_probe.swift
# in a second Terminal tab, within 60s:
osascript -e 'display notification "probe test body" with title "IslandProbe" subtitle "test"'
```

macOS 27 renamed Accessibility to **Device Control and Data Access**
(System Settings > Privacy & Security). Enable it for Terminal, reopen Terminal, run again.
Revoke it afterwards if you like. Paste the output back; it is safe to share.
