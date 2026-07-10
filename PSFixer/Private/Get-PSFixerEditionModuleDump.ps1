function Get-PSFixerEditionModuleDump {
    <#
    .SYNOPSIS
        Lists installed modules (with the same shape as Get-PSFixerModule) for
        a PowerShell edition by actually running the query in that edition's
        own host process - not by guessing at its module paths.
    .PARAMETER Edition
        'PS7' or 'WindowsPowerShell'.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PS7', 'WindowsPowerShell')]
        [string]$Edition
    )

    $exe = Get-PSFixerEditionExecutable -Edition $Edition

    $script = @'
$ErrorActionPreference = "Stop"
$managedKeys = [System.Collections.Generic.HashSet[string]]::new()
if (Get-Command -Name Get-InstalledPSResource -ErrorAction SilentlyContinue) {
    foreach ($r in Get-InstalledPSResource -ErrorAction SilentlyContinue) {
        [void]$managedKeys.Add("$($r.Name)|$($r.Version)")
    }
}
elseif (Get-Command -Name Get-InstalledModule -ErrorAction SilentlyContinue) {
    foreach ($m in Get-InstalledModule -ErrorAction SilentlyContinue) {
        [void]$managedKeys.Add("$($m.Name)|$($m.Version)")
    }
}

Get-Module -ListAvailable -ErrorAction SilentlyContinue | ForEach-Object {
    [pscustomobject]@{
        Name    = $_.Name
        Version = $_.Version.ToString()
        Path    = $_.ModuleBase
        Managed = $managedKeys.Contains("$($_.Name)|$($_.Version)")
    }
} | ConvertTo-Json -Depth 4
'@

    $tempScript = Join-Path -Path $env:TEMP -ChildPath "psfixer-dump-$([guid]::NewGuid()).ps1"
    Set-Content -Path $tempScript -Value $script -Encoding UTF8

    try {
        $json = & $exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $tempScript
        if (-not $json) { return @() }
        $result = $json -join "`n" | ConvertFrom-Json
        # Rebuild real [version] objects - ConvertFrom-Json would otherwise leave them as strings/objects.
        return @($result | ForEach-Object {
            [pscustomobject]@{
                Name    = $_.Name
                Version = [version]$_.Version
                Path    = $_.Path
                Managed = [bool]$_.Managed
            }
        })
    }
    finally {
        Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
    }
}
