# Snapper

A native macOS Redfish client with first-class templates for **Dell iDRAC 9**.
Built with SwiftUI + Swift Charts. Connect to multiple servers at once, monitor
health, power, thermals, storage and inventory, and issue power actions — all
from a flashy, dashboard-driven interface.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-6-orange)

A single-page marketing/download site lives in [`docs/`](docs/index.html) (GitHub Pages-ready): enable Pages for the `docs/` folder, then drop the built `Snapper.zip` alongside it.

## Features

- **Server list** — save servers with credentials (passwords kept in the macOS Keychain, not on disk).
- **Multi-tab** — connect to several servers simultaneously, each in its own tab with live status.
- **Dashboard** — hero health banner, stat tiles, radial gauges (power / hottest sensor / top fan), and a live power-trend chart.
- **Thermal** — temperature & fan bar charts, per-sensor readings with threshold awareness, inlet/CPU trend lines.
- **Power** — consumption gauge with min/avg/max metrics, per-PSU output, voltage, and efficiency.
- **Storage & RAID** — RAID controller details (model, firmware, supported RAID levels, cache), virtual disks, and a physical-drive table. Configure RAID in-app: **create**/**delete** virtual disks (pick RAID level + drives), **convert disks** between RAID and Non-RAID/passthrough, and **blink a drive's locate LED**. RAID controllers are detected robustly even when iDRAC reports an empty `SupportedRAIDTypes`.
- **Inventory** — identity, processors, memory DIMMs, and **network adapters** (brand/model/part/serial + controller firmware) down to per-port link/speed/MAC, **media type**, and **transceiver** details — sourced from the Dell per-function NIC view (SFP+/SFP28/QSFP, optic vs. copper/DAC, vendor/part/serial) — plus logical OS/iDRAC interfaces.
- **Controls** — writable "knobs" applied over Redfish PATCH: chassis **identify/locate LED**, one-time or persistent **boot override** (PXE/Hdd/Cd/BIOS Setup/…), editable **asset tag**, a **power cap** with live capacity-aware slider, and **Virtual Media** (mount/eject a remote ISO/IMG over HTTP/HTTPS/CIFS to boot from).
- **Virtual Console (KVM)** — open the iDRAC HTML5 console in an **embedded WebView window** (self-signed TLS handled) or the **default browser**, plus **VNC** handoff to macOS Screen Sharing (enabling iDRAC's VNC server via attributes when needed).
- **BIOS** — searchable, **registry-driven** browser/editor: pulls `/Bios/BiosRegistry` to render the correct control per attribute (enum **dropdowns**, integer fields with **min/max bounds**, toggles), enforce **validation**, mark read-only attributes, group settings by BIOS menu path, and show help text. Edits stage to the `@Redfish.Settings` object (applied on next reboot) with pending-change tracking; falls back to free-text when no registry is exposed.
- **iDRAC Network & LLDP** (iDRAC tab) — configure the iDRAC NIC (selection, speed/duplex, MTU), hostname/DNS, IPv4 (DHCP or static address/mask/gateway/DNS), VLAN, and the LLDP switch-connection view. Changing the static IP offers to **update the saved server entry and reconnect** to the new address.
- **SNMP & Location** (iDRAC tab) — configure the SNMP agent, community string, protocol/trap format, ports, and trap destinations, plus the server's physical location (Data Center/Room/Aisle/Rack/Slot — the `ServerTopology` group iDRAC reports over SNMP), all via the iDRAC attribute model.
- **Logs** — System Event Log (SEL) with severity filtering and search.
- **Dell iDRAC template** — iDRAC firmware/identity, Service Tag → Express Service Code, a direct Dell support link, and subsystem health rollup.
- **Power control** — On / Graceful Shutdown / Restart / Force Off / NMI, gated by the server's advertised allowable reset values, with confirmation for destructive actions.
- **Auto-refresh** — polls every 10s (toggleable), keeping gauges and charts live.

## Requirements

- macOS 14+
- Swift 6 toolchain (Xcode 16 or Swift Command Line Tools)

## Build & Run

```bash
# Build a runnable .app bundle (release) under ./build
./scripts/build.sh release

# Launch it
open "build/Snapper.app"
```

For day-to-day development:

```bash
swift build            # compile
swift run Snapper   # run the executable directly
```

> The project is a Swift Package (no `.xcodeproj`). `scripts/build.sh` compiles
> with SwiftPM and assembles a proper `.app` bundle with `Info.plist`, then
> codesigns it so Keychain and networking behave on launch.

### Code signing & notarization

The app's bundle identifier is `au.com.athenanetworks.Snapper`. `scripts/build.sh`
signs the bundle (applying `Snapper.entitlements`) with the identity named in
`CODESIGN_IDENTITY`, defaulting to the **Developer ID Application** identity. It
verifies the signature, prints the signing authority, and falls back to ad-hoc
signing if the identity isn't in the keychain.

```bash
# Default: Developer ID signed, runs locally
./scripts/build.sh release

# Local dev with a personal Apple Development identity instead
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./scripts/build.sh release

# Hardened-runtime build (prerequisite for notarization)
HARDENED=1 ./scripts/build.sh release

# Full distribution build: hardened + notarized + stapled (ready to hand out)
NOTARIZE=1 NOTARY_PROFILE=snapper-notary ./scripts/build.sh release
```

`NOTARIZE=1` implies `HARDENED=1`, submits the app to Apple's notary service, staples
the ticket, and re-zips the result to `build/Snapper.zip`. It requires a stored
notarytool keychain profile — create one once with:

```bash
xcrun notarytool store-credentials snapper-notary \
  --apple-id you@example.com --team-id 4S7BG5A4XV \
  --password <app-specific-password>   # or use an App Store Connect API key
```

List available identities with `security find-identity -v -p codesigning`.

- **Apple Development** identities are for running on your own Macs only. Direct
  distribution to others requires the **Developer ID Application** cert (the default
  here) plus notarization, so Gatekeeper opens the downloaded app without warnings.
- **Keychain note:** changing the signing identity (or the bundle ID) changes the app's
  code identity, so saved BMC passwords stored under a previous identity won't be
  readable — re-enter them once. Subsequent builds with the same identity keep them.

## Tests

Model decoding is validated against realistic Dell iDRAC 9 JSON fixtures:

```bash
./tests/run.sh
```

(Command Line Tools lack XCTest, so the tests compile the model sources together
with a standalone runner instead of using `swift test`.)

## TLS / Security notes

- BMCs almost always present **self-signed certificates**; the per-server
  "Allow self-signed certificates" toggle (on by default) trusts them. Turn it
  off for servers with a valid CA-signed chain.
- App Transport Security is relaxed in `Info.plist` because BMC management
  endpoints are typically self-signed and on a trusted management LAN.
- Authentication uses HTTP Basic auth (supported by iDRAC and most BMCs).
  Passwords are stored only in the macOS Keychain.

## Architecture

```
Sources/Snapper/
├── App/            SnapperApp, AppState, ServerConnection (per-tab state + polling)
├── Models/
│   ├── Redfish/    Codable models: ServiceRoot, ComputerSystem, Chassis,
│   │               Thermal, Power, Storage, Inventory, Manager, common types
│   └── SavedServer
├── Networking/     RedfishClient (actor, self-signed TLS, Basic auth),
│                   RedfishService (fetch orchestration), RedfishSnapshot, errors
├── Services/       ServerStore (JSON persistence), KeychainService
└── Views/          ContentView, Sidebar, ConnectionTabBar/View, Dashboard,
                    Thermal, Power, Storage, Inventory, Logs, Dell, Components, Theme
```

- `RedfishClient` is an `actor` for safe concurrent requests; per-tab state lives
  in `@MainActor` `ServerConnection` objects that poll via structured `Task`s.
- `RedfishService` aggregates the collection→member request chain into an
  immutable `RedfishSnapshot` the UI renders, tolerating partial/limited servers.
