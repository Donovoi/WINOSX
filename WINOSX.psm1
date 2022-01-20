# Implement your module commands in this script.
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

function Show-Notification {
  [CmdletBinding()]
  param(
    [string]
    $ToastTitle,
    [string]
    [Parameter(ValueFromPipeline)]
    $ToastText
  )
  if (-not (Get-Module -ListAvailable -Name BurntToast)) {
    Import-RequiredModule -ModuleName BurntToast
  }

  New-BurntToastNotification -Text $ToastTitle,$ToastText
}

# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function *-*
