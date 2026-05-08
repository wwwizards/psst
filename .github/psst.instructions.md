---
description: psst module - PowerShell Script Tester with network telemetry
applyTo: '**/psst/**'
requires:
  - '.github/copilot-instructions.md'
version: 0.5.0
tags: [testing, pester, smoke, integration, telemetry]
status: active
lastModified: 2026-01-07
maintainer: Sol-02
---

## psst Module (PowerShell Script Tester)

### Purpose
Smart Pester test runner with fuzzy pattern matching, category tags, and network context telemetry.

### Quick Start
```powershell
# Install
Import-Module ./psst.psm1 -Force

# Run tests
psst                    # All tests
psst smoke              # Fast precommit checks
psst integration        # Cloud-dependent tests
psst h                  # Fuzzy match (hostpool.Tests.ps1)
psst 07                 # Phase-based (dashboard tests)
```

### Category Tags (v0.5.0)
- **Smoke**: Fast precommit validation (<5s per test)
- **Integration**: Cloud-dependent tests (opt-in with `$env:RUN_INTEGRATION_TESTS=1`)
- **Unit**: Isolated logic tests
- **Sanity**: Quick health checks
- **Cost**: Budget/SKU validation tests
- **Phase07**: Dashboard/telemetry tests
- **Phase08**: Post-deployment diagnostics

### Network Telemetry (v0.5.0)
- **Public IP detection**: Captures operator's external IP via `icanhazip.com`
- **VPN detection**: Checks if IP matches known VPN ranges (10.x, 172.16.x, 192.168.x)
- **NAT status**: Detects if behind NAT gateway
- **Privacy**: Telemetry stored locally (`$env:USERPROFILE\LogicWizards\telemetry\psst-*.jsonl`)

### Mode Toggle
```powershell
# Disable psst intelligence (pure Pester passthrough for debugging)
$env:PSST_MODE = 'OFF'
psst

# Re-enable
$env:PSST_MODE = 'ON'
```

### Dependencies
- **Pester >= 5.7.0**: Auto-installs if missing
- **PowerShell Core (pwsh)**: Required for cross-platform compatibility

### File Structure
```
psst/
  psst.psm1           # Main module logic
  psst.psd1           # Manifest (version, dependencies)
  README.md           # User-facing documentation
  CHANGELOG.md        # Version history (v0.5.0 → v0.1.0 as PesterTester)
  psst.Tests.ps1      # Self-tests (smoke + integration)
  image.png           # Logo/branding
```

### Testing Conventions
```powershell
# Tag tests for psst discovery
Describe 'MyScript smoke' -Tag 'Smoke' {
  It 'file exists' { Test-Path $script:path | Should -BeTrue }
}

Describe 'MyScript integration' -Tag 'Integration' {
  BeforeAll { 
    if (-not $env:RUN_INTEGRATION_TESTS) { 
      Set-ItResult -Skipped -Because 'opt-in required' 
    }
  }
  It 'runs with exit code 0' {
    $p = Start-Process pwsh -ArgumentList '-File', $script:path -PassThru -Wait
    $p.ExitCode | Should -Be 0
  }
}
```

### Troubleshooting
- **"Pester module not found"**: Run `Install-Module Pester -MinimumVersion 5.7.0 -Force`
- **Fuzzy matching not working**: Check `$env:PSST_MODE` (should be empty or 'ON')
- **Network telemetry failing**: Check internet connectivity (psst fails gracefully if offline)
- **Tests not discovered**: Ensure `*.Tests.ps1` naming convention

### Known Issues
- Fuzzy matching may over-match (e.g., `psst a` finds `agile.Tests.ps1` AND `foundation.Tests.ps1`)
- Network telemetry adds ~200ms overhead on first run (cached thereafter)
- Mode toggle requires shell restart (env var scope)

### Roadmap
- Parallel test execution (v0.6.0)
- Watch mode (`psst --watch`) for TDD workflows (v0.6.0)
- CI/CD integration templates (GitHub Actions, Azure Pipelines) (v0.7.0)
- Test result caching (skip unchanged tests) (v0.7.0)

### Related Documentation
- [Main README](../README.md) - User-facing documentation
- [CHANGELOG](../CHANGELOG.md) - Version history
- [Backlog Ticket - README Polish](../../../../../../DATA-TIER/APPS/Agile-Wizard/Idea-Map/NEW-251123-C2S02-STORY-psst-README-Marketing-Polish.md)
