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

Export-ModuleMember -Function $public.BaseName
