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

  Import-RequiredModule -ModuleName BurntToast

  New-BurntToastNotification -Text $ToastTitle,$ToastText
}


function Set-AdminProcess {
    # Verify Running as Admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
    if (-not $isAdmin) {
      Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan; Start-Sleep -Seconds 1

      if ($PSVersionTable.PSEdition -eq "Core") {
        Start-Process pwsh.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
      } else {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
      }

      exit
    }
}

# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function *-*
