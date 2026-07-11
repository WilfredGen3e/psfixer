$PSFixerModuleRoot = $PSScriptRoot

$private = Get-ChildItem -Path (Join-Path $PSFixerModuleRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
$public = Get-ChildItem -Path (Join-Path $PSFixerModuleRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue

foreach ($file in @($private) + @($public)) {
    try {
        . $file.FullName
    }
    catch {
        throw "Failed to dot-source '$($file.FullName)': $_"
    }
}

Set-Alias -Name psdiag -Value Test-PSFixer
Set-Alias -Name psfix -Value Repair-PSFixer
Set-Alias -Name pscat -Value Show-PSFixerCatalog

Export-ModuleMember -Function $public.BaseName -Alias psdiag, psfix, pscat
