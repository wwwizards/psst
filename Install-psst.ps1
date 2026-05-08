#------------------------------------------------------------------------------
# SCRIPT: Install-psst.ps1
#------------------------------------------------------------------------------
#  PURPOSE: Install psst module to user PowerShell modules directory
# ABSTRACT: Copies psst module from SIDE-PROJECTS to global module path for
#           cross-project use. Handles existing installations and verification.
#  CREATED: 2025-11-04 BY: Joe Negron <Joe@LogicWizards.NYC>
# COMPANY: Logic Wizards <LogicWizards.NYC>
#  VERSION: 0.4.0
#  LICENSE: MIT 
#  USAGE: 
#     .\Install-psst.ps1                     # Install to user modules
#     .\Install-psst.ps1 -Scope AllUsers     # Install system-wide (requires admin)
#     .\Install-psst.ps1 -Force              # Overwrite existing installation
#------------------------------------------------------------------------------
[CmdletBinding()]
param(
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',
    
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ModuleVersion = '0.4.0'
$ModuleName = 'psst'

# Get source and destination paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourcePath = $ScriptRoot

# Determine destination based on scope
if ($Scope -eq 'CurrentUser') {
    $DestBase = "$env:USERPROFILE\Documents\PowerShell\Modules"
} else {
    $DestBase = "$env:ProgramFiles\PowerShell\Modules"
    # Check for admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "Installing to AllUsers scope requires administrator privileges. Run PowerShell as Administrator or use -Scope CurrentUser."
        exit 1
    }
}

$DestPath = Join-Path $DestBase "$ModuleName\$ModuleVersion"

Write-Host "Installing $ModuleName v$ModuleVersion..." -ForegroundColor Cyan
Write-Host "  Source: $SourcePath" -ForegroundColor Gray
Write-Host "  Destination: $DestPath" -ForegroundColor Gray

# Check for existing installation
if (Test-Path $DestPath) {
    if ($Force) {
        Write-Warning "Removing existing installation..."
        Remove-Item $DestPath -Recurse -Force
    } else {
        Write-Error "Module already installed at $DestPath. Use -Force to overwrite."
        exit 1
    }
}

# Create destination directory
New-Item -ItemType Directory -Path $DestPath -Force | Out-Null

# Copy module files
$filesToCopy = @('psst.psm1', 'psst.psd1', 'README.md')
foreach ($file in $filesToCopy) {
    $src = Join-Path $SourcePath $file
    if (Test-Path $src) {
        Copy-Item $src -Destination $DestPath -Force
        Write-Host "  ✓ Copied $file" -ForegroundColor Green
    } else {
        Write-Warning "  ⚠ $file not found, skipping"
    }
}

# Verify installation
try {
    Import-Module $ModuleName -Force -ErrorAction Stop
    $installedModule = Get-Module $ModuleName
    
    Write-Host "`n✓ Installation successful!" -ForegroundColor Green
    Write-Host "  Module: $($installedModule.Name)" -ForegroundColor White
    Write-Host "  Version: $($installedModule.Version)" -ForegroundColor White
    Write-Host "  Path: $($installedModule.ModuleBase)" -ForegroundColor White
    
    Write-Host "`nYou can now use 'psst' from any directory!" -ForegroundColor Cyan
    Write-Host "  Example: psst smoke" -ForegroundColor Gray
    Write-Host "  Example: psst 01 03" -ForegroundColor Gray
    
    Write-Host "`nTo auto-load on shell startup, add to your profile:" -ForegroundColor Yellow
    Write-Host "  Import-Module psst" -ForegroundColor Gray
    Write-Host "  Profile location: `$PROFILE" -ForegroundColor Gray
    
} catch {
    Write-Error "Installation verification failed: $_"
    exit 1
}
