#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Run with: .\tests\Invoke-Tests.ps1
# Windows ships Pester 3.4, which cannot parse this syntax.

BeforeAll {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $script:database = Get-Content (Join-Path $repoRoot 'data\endpoints.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:moduleDir = Join-Path $repoRoot 'src\modules'
}

Describe 'Endpoint database' {
    It 'contains entries' {
        $database.endpoints.Count | Should -BeGreaterThan 0
    }

    It 'has no duplicate domains' {
        ($database.endpoints | Group-Object domain | Where-Object Count -gt 1) | Should -BeNullOrEmpty
    }

    It 'has valid required fields on every entry' {
        foreach ($entry in $database.endpoints) {
            $entry.domain   | Should -Not -BeNullOrEmpty
            $entry.service  | Should -Not -BeNullOrEmpty
            $entry.trigger  | Should -Not -BeNullOrEmpty
            $entry.severity | Should -BeIn @('security','update','system','account','telemetry','content','advertising')
            $entry.evidence | Should -BeIn @('documented','observed','community-reported')
            @($entry.categories).Count | Should -BeGreaterThan 0
        }
    }

    It 'documents the evidence basis for non-documented entries' {
        foreach ($entry in $database.endpoints | Where-Object { $_.evidence -ne 'documented' }) {
            $entry.notes | Should -Not -BeNullOrEmpty -Because "$($entry.domain) needs a capture note"
        }
    }
}

Describe 'Collector modules' {
    It 'loads every module without error' {
        foreach ($file in Get-ChildItem $moduleDir -Filter *.ps1) {
            { . $file.FullName } | Should -Not -Throw
        }
    }

    It 'returns a telemetry section from the registry module' -Skip:($env:OS -ne 'Windows_NT') {
        . (Join-Path $moduleDir 'Get-RegistryState.ps1')
        (Get-RegistryState).telemetry | Should -Not -BeNullOrEmpty
    }
}

Describe 'External command output handling' {
    # Native commands return arrays of lines in PowerShell. Regex tests and JSON
    # parsing must operate on joined strings - this class of bug has occurred
    # twice, so it is covered explicitly.

    It 'detects an enabled event log only after joining the line array' {
        $config = @('name: Microsoft-Windows-DNS-Client/Operational', 'enabled: true', 'type: Operational')
        (($config -join "`n") -notmatch 'enabled:\s*true') | Should -BeFalse
    }

    It 'parses multi-line JSON output only after joining the line array' {
        $lines = @('[{"eventName":"Test.Event",', '"count":5},', '{"eventName":"Other.Event","count":2}]')
        $parsed = @((($lines -join '') | ConvertFrom-Json))
        $parsed.Count | Should -Be 2
        $parsed[0].eventName | Should -Be 'Test.Event'
        $parsed[1].count | Should -Be 2
    }
}
