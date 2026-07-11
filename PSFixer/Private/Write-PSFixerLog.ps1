function Write-PSFixerLog {
    <#
    .SYNOPSIS
        Writes an action-log entry and echoes it to the verbose stream.
    .PARAMETER Path
        Log file to append to. If omitted, only writes to the verbose stream.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Critical')]
        [string]$Level = 'Info',

        [string]$Path
    )

    $entry = [pscustomobject]@{
        Timestamp = Get-Date -Format 'o'
        Level     = $Level
        Message   = $Message
    }

    Write-Verbose "[$($entry.Level)] $($entry.Message)"

    if ($Path) {
        $line = "$($entry.Timestamp)`t$($entry.Level)`t$($entry.Message)"
        Add-Content -Path $Path -Value $line -Encoding UTF8
    }

    return $entry
}
