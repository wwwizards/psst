#------------------------------------------------------------------------------
# MODULE: psst (PowerShell Script Tester)
#------------------------------------------------------------------------------
#  PURPOSE: Smart Pester test runner with fuzzy pattern matching
# ABSTRACT: Discovers *.Tests.ps1 files and provides fuzzy matching for easy
#           test execution. Checks for Pester dependency and installs if needed.
# REQUIRES: Pester >= 5.7.0 (auto-installs if missing)
#  CREATED: 2025-11-04 BY: Joe Negron <Joe@LogicWizards.NYC>
# COMPANY: Logic Wizards <LogicWizards.NYC>
#  VERSION: 0.5.0
#  LICENSE: MIT 
#  USAGE: 
#     Import-Module psst
#     psst foundation                        # Run foundation tests
#     psst 01 03 smoke                       # Run multiple test groups
#     psst -Output Minimal                   # Run all with minimal output
#------------------------------------------------------------------------------

# Check for Pester dependency and install if missing
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.7.0' })) {
    Write-Warning "Pester >= 5.7.0 not found. Installing Pester..."
    try {
        Install-Module -Name Pester -MinimumVersion 5.7.0 -Scope CurrentUser -Force -SkipPublisherCheck
        Write-Host "✓ Pester installed successfully" -ForegroundColor Green
    } catch {
        Write-Error "Failed to install Pester: $_"
        throw
    }
}

function psst {
    <#
    .SYNOPSIS
    PowerShell Script Tester - Smart test runner with fuzzy pattern matching and category support.

    .DESCRIPTION
    Discovers all *.Tests.ps1 files in a directory tree and runs tests matching
    fuzzy patterns OR Pester tags. Supports category-based test execution for
    organizing tests by type (smoke, integration, unit, sanity, etc.).

    .PARAMETER RootPath
    Root directory to search for test files. Defaults to current directory.

    .PARAMETER Patterns
    Array of fuzzy match patterns OR category names. Defaults to 'ALL' (runs all tests).
    
    Patterns can match:
    - Folder names (e.g., '01', 'hostpool')
    - Test file names (e.g., 'foundation', 'smoke')
    - Categories mapped to tags: 'smoke', 'integration', 'unit', 'sanity', 'cost', 'phase07', 'phase08'
    
    When a category is specified, psst filters by Pester tags. If no files match by name,
    psst falls back to tag-only filtering across all discovered test files.

    .PARAMETER Output
    Pester output verbosity: None, Minimal, Normal, Detailed, Diagnostic

    .PARAMETER PassThru
    Return Pester result object instead of just exit code

    .PARAMETER ExcludePattern
    Glob pattern for paths to exclude (e.g., '*\archive\*')

    .PARAMETER Quiet
    Suppress custom summary output (only show Pester's built-in summary)

    .EXAMPLE
    psst foundation
    # Run foundation tests by filename match
    
    .EXAMPLE
    psst smoke
    # Run all tests tagged 'Smoke' (or with 'smoke' in filename)
    
    .EXAMPLE
    psst integration
    # Run all tests tagged 'Integration' (cloud-dependent tests)

    .EXAMPLE
    psst 01 03 -Output Detailed
    # Run tests in phases 01 and 03 with detailed output

    .EXAMPLE
    $result = psst ALL -PassThru
    # Get full Pester result object for programmatic analysis
    
    .NOTES
    Category → Tag Mapping (Generic):
    - smoke       → Smoke       (fast precommit checks)
    - integration → Integration (cloud-dependent tests)
    - unit        → Unit        (isolated unit tests)
    - sanity      → Sanity      (basic health checks)
    - cost        → Cost        (budget/SKU validation)
    - azure       → Azure       (cloud/vendor-specific)
    - other       → catch-all for tests outside standard QA tags (uses ExcludeTag)
    
    Extensibility Pattern:
    Users can define custom categories via:
    1. Filename patterns: psst phase07, psst 03, psst hostpool
    2. Pester tags in Describe blocks: Describe "My Tests" -Tag 'Phase07','CustomTag' { ... }
    3. Hybrid: psst smoke matches files with 'smoke' in name OR tests tagged 'Smoke'
    
    This keeps psst generic while allowing project-specific organization.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        [string[]]$Patterns = @('ALL'),
        
        [string]$RootPath = '.',
        
        [ValidateSet('None','Minimal','Normal','Detailed','Diagnostic')]
        [string]$Output = 'Detailed',
        
        [switch]$PassThru,
        
        [string]$ExcludePattern = '*\archive\*',
        
        [switch]$Quiet
    )

    $ErrorActionPreference = 'Stop'
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force | Out-Null
        Write-Host "[psst] Set-ExecutionPolicy Bypass -Scope Process (local dev)" -ForegroundColor DarkGray
    } catch {
        Write-Warning "[psst] Could not set execution policy: $_"
    }
    $RootPath = (Resolve-Path $RootPath).Path

    # Check psst mode via environment variable PSST (ON by default, OFF for pure Pester passthrough)
    $psstMode = if ($env:PSST -eq 'OFF') { 'OFF' } else { 'ON' }
    
    if ($psstMode -eq 'OFF') {
        Write-Host "⚙️  TESTER = psst: " -NoNewline -ForegroundColor Yellow
        Write-Host "OFF" -ForegroundColor Red
        Write-Host "Falling through to default Pester functionality...`n" -ForegroundColor Gray
    } else {
        Write-Host "⚙️  TESTER = psst: " -NoNewline -ForegroundColor Cyan
        Write-Host "ON" -ForegroundColor Green
        Write-Host "Invoking Extended Test Intelligence...`n" -ForegroundColor Gray
    }

    # Discover all test files
    Write-Verbose "Scanning for test files in $RootPath..."
    $allTests = Get-ChildItem -Path $RootPath -Recurse -Filter "*.Tests.ps1" -File |
        Where-Object { $_.FullName -notlike $ExcludePattern } |
        Select-Object FullName, Name, @{N='Folder';E={Split-Path (Split-Path $_.FullName -Parent) -Leaf}}

    if ($allTests.Count -eq 0) {
        Write-Warning "No test files found matching pattern '*.Tests.ps1' in $RootPath"
        return 1
    }

    Write-Verbose "Found $($allTests.Count) test files total"

    # If psst mode is OFF, skip all intelligence and just run Pester on all discovered tests
    if ($psstMode -eq 'OFF') {
        Write-Host "🧪 Running ALL discovered tests with default Pester behavior..." -ForegroundColor Yellow
        Write-Host "   (No fuzzy matching, no tag filtering, no telemetry)`n" -ForegroundColor DarkGray
        
        $pesterConfig = @{
            Run = @{
                Path = $allTests.FullName
                PassThru = $true
            }
            Output = @{
                Verbosity = $Output
            }
        }
        
        try {
            $result = Invoke-Pester -Configuration $pesterConfig
            
            if (-not $Quiet) {
                $successRate = if ($result.TotalCount -gt 0) {
                    [math]::Round(($result.PassedCount / $result.TotalCount) * 100, 1)
                } else { 0 }
                Write-Host "`n$("="*80)" -ForegroundColor Cyan
                Write-Host "PESTER SUMMARY (psst mode: OFF)" -ForegroundColor Yellow
                Write-Host "$("="*80)" -ForegroundColor Cyan
                Write-Host "Total Tests:   $($result.TotalCount)" -ForegroundColor White
                Write-Host "Passed:        $($result.PassedCount)" -ForegroundColor Green
                Write-Host "Failed:        $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Gray' })
                Write-Host "Skipped:       $($result.SkippedCount)" -ForegroundColor Yellow
                Write-Host "Duration:      $($result.Duration)" -ForegroundColor White
                Write-Host "$("="*80)" -ForegroundColor Cyan
            }
            
            if ($PassThru) {
                return $result
            }
            return ($result.FailedCount -gt 0 ? 1 : 0)
            
        } catch {
            Write-Error "Test execution failed: $_"
            return 1
        }
    }

    # Normal psst mode (ON): fuzzy matching, tags, telemetry
    # Category mapping (patterns -> Pester tags)
    # Note: Users can define custom categories via:
    #   1. Filename patterns (e.g., 'foundation', '03-hostpool')
    #   2. Describe -Tag annotations in test files (e.g., -Tag 'Smoke','MyCustomTag')
    #   3. Hybrid: filename match + tag filtering
    $categoryTagMap = @{
        'smoke'       = @('Smoke')
        'integration' = @('Integration')
        'unit'        = @('Unit')
        'sanity'      = @('Sanity')
        'cost'        = @('Cost')
        'azure'       = @('Azure')
    }

    # Determine if "other" (catch-all) was requested. If so, we will exclude
    # all known standard QA tags and include tests that have no tags or only
    # project-specific tags.
    $isOtherRequested = $false
    foreach ($p in $Patterns) {
        if ($p -and $p.ToLower() -eq 'other') { $isOtherRequested = $true }
        if ($p -and $p.ToLower() -eq 'untagged') { $isOtherRequested = $true }
    }

    $requestedTags = @()
    foreach ($p in $Patterns) {
        $k = $p.ToLower()
        if ($categoryTagMap.ContainsKey($k)) {
            $requestedTags += $categoryTagMap[$k]
        }
    }
    $requestedTags = $requestedTags | Select-Object -Unique

    # Build known standard tags list for ExcludeTag when using 'other'
    $knownTags = @()
    foreach ($v in $categoryTagMap.Values) { $knownTags += $v }
    $knownTags = $knownTags | Select-Object -Unique

    # Filter tests based on patterns (folders / filenames). If only category patterns are provided
    # and no file matches by name, we let Pester tag filter do the selection.
    if ($Patterns.Count -eq 1 -and $Patterns[0] -eq 'ALL') {
        $selectedTests = $allTests
        Write-Host "🧪 Running ALL tests ($($selectedTests.Count) files)..." -ForegroundColor Cyan
    } else {
        $selectedTests = $allTests | Where-Object {
            $test = $_
            $matched = $false
            foreach ($pattern in $Patterns) {
                if ($test.Folder -like "*$pattern*" -or $test.Name -like "*$pattern*") {
                    $matched = $true
                    break
                }
            }
            $matched
        }
        
        if ($selectedTests.Count -eq 0) {
            if ($requestedTags.Count -gt 0) {
                # Fall back to all tests; Pester will filter by tags
                $selectedTests = $allTests
                Write-Host "🧪 No files matched by name. Falling back to TAG filter only: $($requestedTags -join ', ')" -ForegroundColor Yellow
            } else {
                Write-Warning "No tests matched patterns: $($Patterns -join ', ')"
                Write-Host "`nAvailable test files:" -ForegroundColor Yellow
                $allTests | Sort-Object Folder, Name | ForEach-Object {
                    Write-Host "  [$($_.Folder)] $($_.Name)" -ForegroundColor Gray
                }
                return 1
            }
        }
        
        $scopeMsg = if ($isOtherRequested) {
            " (other: excluding tags: $($knownTags -join ', '))"
        } elseif ($requestedTags.Count -gt 0) {
            " (tags: $($requestedTags -join ', '))"
        } else { '' }
        Write-Host "🧪 Running $($selectedTests.Count) test(s) matching patterns: $($Patterns -join ', ')$scopeMsg" -ForegroundColor Cyan
    }

    # Display selected tests
    Write-Host "`nSelected tests:" -ForegroundColor Green
    $selectedTests | Sort-Object Folder, Name | ForEach-Object {
        Write-Host "  ✓ [$($_.Folder)] $($_.Name)" -ForegroundColor DarkGray
    }
    Write-Host ""

    # Run tests using Pester
    $pesterConfig = @{
        Run = @{
            Path = $selectedTests.FullName
            PassThru = $true
        }
        Output = @{
            Verbosity = $Output
        }
    }

    if ($isOtherRequested) {
        if ($requestedTags.Count -gt 0) {
            Write-Warning "'other' was requested; ignoring additional tag filters ($($requestedTags -join ', ')) and using ExcludeTag."
        }
        $pesterConfig['Filter'] = @{ ExcludeTag = $knownTags }
    } elseif ($requestedTags.Count -gt 0) {
        $pesterConfig['Filter'] = @{ Tag = $requestedTags }
    }

    try {
        $result = Invoke-Pester -Configuration $pesterConfig

        # Compute success metrics
        $successRate = if ($result.TotalCount -gt 0) {
            [math]::Round(($result.PassedCount / $result.TotalCount) * 100, 1)
        } else { 0 }
        $successColor = if ($successRate -eq 100) { 'Green' }
                        elseif ($successRate -ge 80) { 'Yellow' }
                        elseif ($successRate -ge 50) { 'DarkYellow' }
                        else { 'Red' }

        # Build context-aware command string
        $invokedCommand = if ($MyInvocation.Line) {
            $MyInvocation.Line.Trim()
        } elseif ($Patterns -and $Patterns.Count -gt 0 -and $Patterns[0] -ne 'ALL') {
            "psst $($Patterns -join ' ')"
        } else {
            'psst'
        }

        # Capture workstation telemetry (via Get-NetworkContext if available)
        $thisContext = @{
            hostIP = $null
            vpnDetected = $false
            natDetected = $false
            scriptName = 'psst (PowerShell Script Tester)'
            invocation = $invokedCommand
            timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
            testFiles = $selectedTests.Name -join ', '
            rootPath = $RootPath
        }

        # Try to get network context (requires common-library.ps1 dot-sourced or function available)
        try {
            if (Get-Command Get-NetworkContext -ErrorAction SilentlyContinue) {
                $netCtx = Get-NetworkContext -ErrorAction SilentlyContinue
                if ($netCtx) {
                    $thisContext.hostIP = $netCtx.PublicIp
                    $thisContext.vpnDetected = $netCtx.IsVpnDetected
                    $thisContext.natDetected = $netCtx.IsLikelyNATed
                }
            } else {
                # Fallback: direct IP fetch
                $ip = (Invoke-RestMethod -Uri 'https://icanhazip.com' -TimeoutSec 2 -ErrorAction SilentlyContinue).Trim()
                if ($ip -match '^\d{1,3}(\.\d{1,3}){3}$') {
                    $thisContext.hostIP = $ip
                }
            }
        } catch {
            # Silently fail; network context is optional
        }

        # Custom summary output (skip if -Quiet)
        if (-not $Quiet) {
            $now = Get-Date
            Write-Host ""
            Write-Host ("="*80) -ForegroundColor Cyan
            Write-Host ("TEST SUMMARY: {0}%" -f $successRate) -ForegroundColor $successColor
            Write-Host ("="*80) -ForegroundColor Cyan
            Write-Host ("Command:       {0}" -f $invokedCommand) -ForegroundColor Gray
            Write-Host ("Total Tests:   {0}" -f $result.TotalCount) -ForegroundColor White
            Write-Host ("Passed:        {0}" -f $result.PassedCount) -ForegroundColor Green
            Write-Host ("Failed:        {0}" -f $result.FailedCount) -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Gray' })
            Write-Host ("Skipped:       {0}" -f $result.SkippedCount) -ForegroundColor Yellow
            Write-Host ("Duration:      {0}" -f $result.Duration) -ForegroundColor White
            
            # If there are failed tests, print a concise list for quick triage
            if ($result.FailedCount -gt 0) {
                Write-Host ""; Write-Host "Failed tests:" -ForegroundColor Red
                $failedTests = @()
                try {
                    if ($null -ne $result.TestResult) {
                        $failedTests = $result.TestResult | Where-Object { $_.Result -eq 'Failed' -or $_.Outcome -eq 'Failed' }
                    }
                } catch {}
                if (-not $failedTests -and $null -ne $result.Tests) {
                    try { $failedTests = $result.Tests | Where-Object { $_.Result -eq 'Failed' -or $_.Outcome -eq 'Failed' } } catch {}
                }
                $maxList = 15
                $shown = 0
                foreach ($ft in ($failedTests | Select-Object -First $maxList)) {
                    $path = $null; $desc = $null; $ctx = $null; $name = $null
                    try { $path = if ($ft.Path) { Split-Path $ft.Path -Leaf } } catch {}
                    try { $desc = $ft.Describe } catch {}
                    try { $ctx  = $ft.Context } catch {}
                    try { $name = if ($ft.Name) { $ft.Name } elseif ($ft.Test) { $ft.Test } else { $null } } catch {}
                    $parts = @()
                    if ($path) { $parts += "[$path]" }
                    if ($desc) { $parts += $desc }
                    if ($ctx)  { $parts += $ctx }
                    if ($name) { $parts += $name }
                    $line = ' - ' + ($parts -join ' | ')
                    Write-Host $line -ForegroundColor DarkRed
                    $shown++
                }
                $remaining = ($failedTests.Count - $shown)
                if ($remaining -gt 0) {
                    Write-Host ("   ... (+{0} more)" -f $remaining) -ForegroundColor DarkRed
                }
            }
            Write-Host ("="*80) -ForegroundColor Cyan
            Write-Host "  - cmd: $invokedCommand" -ForegroundColor Gray
            Write-Host "  - now: $($now.ToString('dd/MM/yyyy HH:mm:ss'))" -ForegroundColor Gray
            if ($thisContext.hostIP) {
                Write-Host "  - ip:  $($thisContext.hostIP)" -ForegroundColor DarkCyan
                if ($thisContext.vpnDetected) {
                    Write-Host "  - vpn: detected" -ForegroundColor Magenta
                }
                if ($thisContext.natDetected) {
                    Write-Host "  - nat: yes" -ForegroundColor DarkYellow
                }
            }
        }

        # Write telemetry event (if psstel available)
        try {
            if (Get-Command Write-TelemetryEvent -ErrorAction SilentlyContinue) {
                $telemetryMetadata = @{
                    script = $invokedCommand
                    total = $result.TotalCount
                    passed = $result.PassedCount
                    failed = $result.FailedCount
                    skipped = $result.SkippedCount
                    duration = $result.Duration.TotalSeconds
                    hostIP = $thisContext.hostIP
                    vpnDetected = $thisContext.vpnDetected
                    natDetected = $thisContext.natDetected
                }
                $telemetryResult = if ($result.FailedCount -eq 0) { 'Success' } else { 'Failed' }
                $telemetryMessage = "psst test run: $($result.PassedCount)/$($result.TotalCount) passed"
                Write-TelemetryEvent -EventType 'Test' -Tenant 'Phoenix-CPAs' -Project 'VDI-Manager' -Source 'Test' -Phase 'smoke' -Result $telemetryResult -Message $telemetryMessage -Metadata $telemetryMetadata
                Write-Host "[TELEMETRY DEBUG] Write-TelemetryEvent completed" -ForegroundColor Magenta
            } else {
                Write-Host "[TELEMETRY DEBUG] Write-TelemetryEvent command not found" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[TELEMETRY ERROR] $_" -ForegroundColor Red
        }

        if ($PassThru) {
            return $result
        }

        # Return exit code
        return ($result.FailedCount -gt 0 ? 1 : 0)

    } catch {
        Write-Error "Test execution failed: $_"
        return 1
    }
}

# Export module members
Export-ModuleMember -Function psst
