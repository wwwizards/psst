# psst - Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.5.0] - 2025-11-14

### Added
- **Category-based test execution** via Pester tags (`smoke`, `integration`, `unit`, `sanity`, `cost`, `phase07`, `phase08`)
- **Tag→Category mapping**: Automatically filters tests by Pester tags when category patterns are used
- **Fallback behavior**: If no files match by name, falls back to tag-only filtering across all test files
- **Mode toggle**: `$env:PSST_MODE='ON|OFF'` for debugging/troubleshooting
  - `OFF` mode bypasses all psst intelligence and uses pure Pester passthrough
  - Visual indicators show current mode at startup
- **Enhanced help documentation**: Updated `Get-Help psst` with category examples and mapping table
- **Network context telemetry**: Captures public IP, VPN detection, NAT status (when `Get-NetworkContext` available)
- **Telemetry footer**: Displays operator IP, VPN/NAT flags in test summary

### Changed
- **Pester dependency**: Now requires Pester >= 5.7.0 (auto-installs if missing)
- **Enhanced summary output**: Shows category tags, success rate percentage, detailed telemetry
- **README**: Comprehensive documentation for category tags, mode toggle, and troubleshooting

### Fixed
- Tag filtering now works correctly with filename fallback logic
- Mode toggle prevents psst logic from interfering when debugging test issues

---

## [0.4.0] - 2025-11-04

### Changed
- **Rebranded** from PesterTester to `psst` (PowerShell Script Tester)
- Removed `pt` alias for cleaner module namespace
- Auto-install Pester if not present (>= 5.5.0 at time)
- Global installation ready (instructions in README)

### Added
- Module manifest (`.psd1`) for proper PowerShell Gallery support
- `Install-psst.ps1` helper script for frictionless setup

---

## [1.1.0] - 2025-11-03 (as PesterTester)

### Added
- Fuzzy pattern matching for test discovery
- Multi-pattern support (run multiple test groups with one command)
- Archive folder exclusion (automatic `*\archive\*` filtering)
- Colored summary output with success metrics
- Exit code support for CI/CD pipelines

---

## [1.0.1] - 2025-11-02 (as PesterTester)

### Fixed
- Path resolution issues on recursive searches
- Improved error messages for missing test files

---

## [1.0.0] - 2025-11-01 (as PesterTester)

### Added
- Initial release as PesterTester
- Basic test discovery and execution
- Pattern matching for folder/file names
