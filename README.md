<p align="center">
  <img src="assets/brand/lockup-horizontal-light.svg#gh-light-mode-only" alt="Krasnotch" width="420">
  <img src="assets/brand/lockup-horizontal-dark.svg#gh-dark-mode-only" alt="Krasnotch" width="420">
</p>

<p align="center">Your notch knows when your agent needs you.</p>

Krasnotch is a macOS menu bar app that lights up the MacBook notch while your coding agents work. It shows a steady glow while Claude Code is busy, a different one when it needs your input, and a short flash when it's done. Click the notch to jump straight back to the terminal tab, editor or T3 Code thread the agent runs in.

**Website:** [krasnotch.vercel.app](https://krasnotch.vercel.app)

## Download

Grab the latest **Krasnotch-x.y.z.dmg** from [Releases](https://github.com/mihaeltomic/krasnotch/releases/latest), open it and drag Krasnotch to Applications. Builds are universal (Apple silicon and Intel) and need macOS 15 or later.

Releases from 0.2.2 on are signed with a Developer ID and notarized by Apple, so they open without a Gatekeeper warning.

## Set up

1. Open Krasnotch. A small block with two eyes appears in the menu bar.
2. Choose **Connect Claude Code** from the menu. Krasnotch adds hooks to `~/.claude/settings.json`, keeps a backup next to it, and leaves your other hooks untouched.
3. Start a new Claude Code session. The notch glows while it works.

Open **Settings…** to choose the animation, colors, thickness, glow intensity, the dithered look, or the **Magic?** glitter mode for each state.

If you also run Alcove, NotchNook or another app that draws over the notch, turn on **Wrap around other notch apps**. The glow and pill then follow that app's shape instead of hiding behind it. macOS asks for Screen Recording permission the first time; reopen Krasnotch after allowing it.

### Other agents and scripts

Anything can report a state by sending a request to Krasnotch's socket:

```sh
curl --unix-socket "$HOME/Library/Application Support/Krasnotch/events.sock" \
  "http://localhost/state?session=my-agent&value=working"   # working | needsInput | done | idle
```

## Privacy and security

- Krasnotch makes no network connections. Events arrive over a Unix domain socket in `~/Library/Application Support/Krasnotch/`. The folder is `0700`, the socket is `0600`, and every connection's peer uid is checked. Browsers, other macOS users and other machines can't reach it.
- Hook payloads stay on your Mac. The app reads only the event name, session id, tool name, notification type and working directory.
- **Wrap around other notch apps** is off by default and is the only feature that needs Screen Recording. While the glow is on, Krasnotch captures just the windows other apps hang over the notch, at one pixel per point and several times a second, to measure their outline. Each capture is read for its shape and discarded. Nothing is saved, and the rest of your screen is never captured.
- Clicking the notch opens only what the session's own process ancestry points to (Terminal, iTerm2, VS Code, Cursor or a T3 Code thread). Terminal tabs are selected with AppleScript, so macOS asks once for Automation permission.

Found a security issue? Please open a private security advisory on this repository rather than a public issue.

## Build from source

Requires Xcode 16 or later.

```sh
swift test                         # run the tests
scripts/build-app.sh               # build/Krasnotch.app (universal, ad-hoc signed)
open build/Krasnotch.app
VERSION=0.2.0 scripts/package.sh   # dist/Krasnotch-0.2.0.dmg, .zip and SHA256SUMS.txt
```

## Releasing

Push a version tag and GitHub Actions tests, builds, packages and publishes the DMG and zip to Releases:

```sh
git tag v0.2.0 && git push origin v0.2.0
```

Releases are currently signed and notarized locally instead. Store notary credentials once with `xcrun notarytool store-credentials krasnotch`, then run:

```sh
DEVELOPER_ID="Developer ID Application: Name (TEAMID)" NOTARY_PROFILE=krasnotch VERSION=0.2.3 scripts/package.sh
gh release create v0.2.3 dist/* --title "Krasnotch 0.2.3" --generate-notes
```

Creating the release also pushes the tag, which starts the workflow above; cancel that run so it doesn't race the local release. To have CI sign and notarize instead, add these repository secrets: `DEVELOPER_ID_P12` (base64 of the exported certificate), `DEVELOPER_ID_P12_PASSWORD`, `DEVELOPER_ID_NAME`, `APPLE_ID`, `APPLE_TEAM_ID` and `APPLE_APP_PASSWORD` (an app-specific password).

## License

[MIT](LICENSE). The logo uses [IMD Grotesk](https://www.imd-grotesk.com/) and the website uses [Geist](https://vercel.com/font), both under the SIL Open Font License.
