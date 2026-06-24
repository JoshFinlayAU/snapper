# Snapper

A native macOS Redfish client with first-class templates for **Dell iDRAC 9**.
Built with SwiftUI + Swift Charts. Connect to multiple servers at once, monitor
health, power, thermals, storage and inventory, and issue power actions — all
from a flashy, dashboard-driven interface.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-6-orange)

## Features

- **Server list** — save servers with credentials (passwords kept in the macOS Keychain, not on disk).
- **Multi-tab** — connect to several servers simultaneously, each in its own tab with live status.
- **Dashboard** — hero health banner, stat tiles, radial gauges (power / hottest sensor / top fan), and a live power-trend chart.
- **Thermal** — temperature & fan bar charts, per-sensor readings with threshold awareness, inlet/CPU trend lines.
- **Power** — consumption gauge with min/avg/max metrics, per-PSU output, voltage, and efficiency.
- **Storage** — controllers and a physical-drive table (media type, capacity, bus, health, predicted-failure flags).
- **Inventory** — identity, processors, memory DIMMs, and network interfaces.
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
> ad-hoc codesigns it so Keychain and networking behave on launch.

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
