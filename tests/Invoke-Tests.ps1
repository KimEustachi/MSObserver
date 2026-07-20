<#
.SYNOPSIS
    Runs the MSObserver test suite with a compatible Pester version.

.DESCRIPTION
    Windows ships Pester 3.4, which cannot run Pester 5 test syntax. This
    script verifies that Pester 5 or newer is available, offers to install it
    into the current user scope, and imports the correct version explicitly.

.EXAMPLE
    .\tests\Invoke-Tests.ps1
#>
[CmdletBinding()]
param(
    [switch]$InstallIfMissing
)

Set-StrictMode -Version 3

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$pester = Get-Module -ListAvailable -Name Pester |
          Where-Object { $_.Version -ge [version]'5.0.0' } |
          Sort-Object Version -Descending |
          Select-Object -First 1

if (-not $pester) {
    if (-not $InstallIfMissing) {
        Write-Host ''
        Write-Warning 'Pester 5 wird benoetigt. Windows liefert nur Pester 3.4 mit.'
        Write-Host ''
        Write-Host '  Installation:' -ForegroundColor Cyan
        Write-Host '  Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser'
        Write-Host ''
        Write-Host '  Oder direkt:  .\tests\Invoke-Tests.ps1 -InstallIfMissing'
        Write-Host ''
        return
    }

    Write-Host ''
    Write-Host '  Pester 5 wird installiert ...' -ForegroundColor Cyan
    Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser

    $pester = Get-Module -ListAvailable -Name Pester |
              Where-Object { $_.Version -ge [version]'5.0.0' } |
              Sort-Object Version -Descending |
              Select-Object -First 1
    if (-not $pester) { throw 'Installation fehlgeschlagen.' }
}

# Remove the auto-loaded Pester 3 from the session before importing v5.
Remove-Module Pester -Force -ErrorAction SilentlyContinue
Import-Module Pester -MinimumVersion 5.0 -Force

Write-Host ''
Write-Host "  Pester $($pester.Version)" -ForegroundColor Cyan
Write-Host ''

Invoke-Pester -Path $scriptRoot -Output Detailed
