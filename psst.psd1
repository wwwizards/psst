@{
    RootModule = 'psst.psm1'
    ModuleVersion = '0.5.0'
    GUID = 'a1b2c3d4-5e6f-7890-abcd-ef1234567890'
    Author = 'Joe Negron'
    CompanyName = 'Logic Wizards'
    Copyright = '(c) 2025 Logic Wizards. All rights reserved.'
    Description = 'psst - PowerShell Script Tester. Smart Pester test runner with fuzzy pattern matching, network context telemetry, and auto-discovery. Run tests as easy as: psst foundation, psst 01, psst smoke.'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
    )
    FunctionsToExport = @('psst')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Testing', 'Pester', 'DevOps', 'CI/CD', 'Test-Runner', 'Automation', 'psst', 'Telemetry')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/LogicWizardsNYC/psst'
            IconUri = ''
            ReleaseNotes = @'
## v0.5.0 (2025-11-14)
- **Network context telemetry**: Captures public IP, VPN detection, NAT status via Get-NetworkContext
- **Enhanced summary**: Displays operator IP, VPN, NAT in test summary footer
- **Formal Pester dependency**: Requires Pester >= 5.7.0 (auto-installs if missing)
- **Invocation tracking**: Captures full command line for audit/telemetry
- **Timestamp metadata**: ISO8601 timestamps for all test runs
- Improved fallback: direct IP fetch if Get-NetworkContext unavailable

## v0.4.0 (2025-11-04)
- **BREAKING**: Rebranded from PesterTester to psst (PowerShell Script Tester)
- **BREAKING**: Function renamed from Invoke-SmartTest to psst
- **BREAKING**: Removed 'test' alias export (use 'psst' directly)
- Auto-installs Pester dependency if missing
- Configured for global user module path installation
- Cleaned summary output (table format with borders)
- Improved path resolution with Resolve-Path
- Ready for cross-project use

## Previous Versions (as PesterTester)
- v1.1.0: Simplified summary, added test alias
- v1.0.1: Added custom summary output
- v1.0.0: Initial release with fuzzy matching
'@
        }
    }
}
