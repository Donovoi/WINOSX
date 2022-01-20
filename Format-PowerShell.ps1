Install-Module -Name Powershell-Beautifier -Force -AllowClobber
Import-Module -Name Powershell-Beautifier
$files = Get-ChildItem *.ps*
$files.ForEach{ Edit-DTWBeautifyScript -SourcePath $_ }
