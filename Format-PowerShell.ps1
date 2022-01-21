function Import-RequiredModule {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$ModuleName
  )

  if ($PSVersionTable.PSVersion -lt '6.2') {
    Set-PSRepository -Name psgallery -InstallationPolicy Trusted
    Install-PackageProvider -Name NuGet -Force | Out-Null
  }

  foreach ($Module in $ModuleName) {
    try {
      if (-not (Get-Module -ListAvailable -Name $Module)) {
        Write-Output -Message "Installing $Module module"
        Install-Module -Name $Module -Force -AllowClobber | Out-Null
        Import-Module -Name $Module
      } else {
        Import-Module -Name $Module
      }
    } catch {
      Write-Output "Can't install $Module. See Error Below:"
      Write-Out "$_"
    }

  }

}

Import-RequiredModule -ModuleName Powershell-Beautifier
$files = Get-ChildItem *.ps*
$files.ForEach{ Edit-DTWBeautifyScript -SourcePath $_ }
