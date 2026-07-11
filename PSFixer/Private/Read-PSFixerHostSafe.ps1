function Read-PSFixerHostSafe {
    <#
    .SYNOPSIS
        Read-Host with a default answer for blank input and a safe fallback
        if Read-Host itself throws (same host-quirk protection as the other
        interactive-prompt helpers in this module).
    .PARAMETER Prompt
        Prompt text (without the "[Default]" suffix - that's added automatically).
    .PARAMETER Default
        Value returned when the user presses Enter without typing anything,
        or when Read-Host fails.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [string]$Default
    )

    try {
        $answer = Read-Host -Prompt "$Prompt [$Default]"
    }
    catch {
        Write-Verbose "Kon niet interactief vragen ('$Prompt'): $_. Val terug op '$Default'."
        return $Default
    }

    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $Default
    }

    return $answer
}
