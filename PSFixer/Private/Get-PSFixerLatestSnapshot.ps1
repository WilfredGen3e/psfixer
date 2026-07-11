function Get-PSFixerLatestSnapshot {
    <#
    .SYNOPSIS
        Returns the most recent Reset-PSFixerEnvironment inventory snapshot
        file under the given directory, or $null if there isn't one.
    .PARAMETER SnapshotPath
        Directory to look in (the same directory Reset-PSFixerEnvironment
        writes its snapshots to).
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        [string]$SnapshotPath
    )

    Get-ChildItem -Path $SnapshotPath -Filter 'inventory-*.json' -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 1
}
