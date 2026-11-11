# Bean – Keep Awake

A tiny, free, open-source menu bar app that keeps your Mac awake.

Click the bean, choose what to keep awake, press **Start**. Run until you stop it, or set a timer. There is no Dock icon and no window, and the app collects no data.

## Features

- **Five keep-awake options**, mix and match: display, idle sleep, disk, system sleep on AC power, and "user active".
- **Accurate timers** from 1 minute to 24 hours. They count real time, so a session that should have ended while the Mac slept ends as soon as it wakes.
- **Nothing left behind.** Stop, timer expiry and quit all release every request, and macOS releases them too if the app ever crashes.
- **Launch at Login** through `SMAppService`, off until you turn it on.
- **Sandboxed, Hardened Runtime, no network access**, full VoiceOver labels, and light and dark mode.
- **macOS 13 Ventura or later**, on Apple silicon and Intel.

## Install

Download the latest `Bean-x.y.dmg` from [Releases](../../releases), open it, and drag **Bean** to **Applications**. Release builds are signed with a Developer ID and notarized by Apple.

## Build from source

You need Xcode 26 or later.

```bash
swift test --package-path BeanCore
```

```bash
open Bean.xcodeproj
```

In Xcode, choose your own team under Signing & Capabilities, then run.

To make a signed, notarized DMG, copy `Config/Local.env.example` to `Config/Local.env`, set your Team ID, store notarization credentials once, then run the release script:

```bash
xcrun notarytool store-credentials BeanNotary --apple-id <your-apple-id> --team-id <TEAM_ID>
```

```bash
scripts/release.sh
```

## How it works

Each option holds one IOKit power assertion:

| Option | Assertion |
|---|---|
| Display | `kIOPMAssertionTypePreventUserIdleDisplaySleep` |
| Idle | `kIOPMAssertionTypePreventUserIdleSystemSleep` |
| Disk | `kIOPMAssertPreventDiskIdle` |
| System (AC) | `kIOPMAssertionTypePreventSystemSleep` |
| User active | `IOPMAssertionDeclareUserActivity` |

All logic lives in the `BeanCore` Swift package, which has its own unit tests, including tests against the real power-management system. The app target in `Bean/` is a thin SwiftUI layer.

## Privacy

See [PRIVACY.md](PRIVACY.md). Short version: nothing is collected, and nothing leaves your Mac.

## License

[MIT](LICENSE)
