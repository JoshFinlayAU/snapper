#!/usr/bin/env bash
# Compile and run the standalone model decoding tests.
# Command Line Tools lack XCTest, so we compile the model sources together with
# the test runner into a single executable rather than using `swift test`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$(xcrun --show-sdk-path)"

SOURCES=(
    "$ROOT"/Sources/Snapper/Models/Redfish/RedfishCommon.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/ServiceRoot.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/ComputerSystem.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/Chassis.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/Thermal.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/Power.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/Storage.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/Inventory.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/Manager.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/VirtualMedia.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/NetworkAdapter.swift
    "$ROOT"/Sources/Snapper/Models/Redfish/BiosRegistry.swift
    "$ROOT"/Sources/Snapper/Networking/RedfishSnapshot.swift
    "$ROOT"/tests/Fixtures.swift
    "$ROOT"/tests/main.swift
)

OUT="$(mktemp -d)/model-tests"
echo "==> compiling model tests"
swiftc -sdk "$SDK" "${SOURCES[@]}" -o "$OUT"
echo "==> running"
"$OUT"
