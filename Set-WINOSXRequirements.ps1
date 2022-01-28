Import-Module .\WINOSX.psm1
Remove-Module -Name "$PSScriptRoot\Requirements\Requirements.psd1" -ErrorAction SilentlyContinue
#Import-RequiredModule -ModuleName @("$PSScriptRoot\Requirements\Requirements.psd1") -Verbose
Import-Module -Name "$PSScriptRoot\Requirements\Requirements.psd1"

# make sure script doesnt fail when downloading
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$requirements = @(
  @{
    Describe = "We are running as an Administrator"
    Set = {
      Set-AdminProcess
    }
  },
  @{
    Describe = "Required features are enabled in Windows"
    Test =
    {
      @("Microsoft-Windows-Subsystem-Linux","VirtualMachinePlatform").ForEach{
        if ($(Get-WindowsOptionalFeature -Online -FeatureName $_).State -eq 'Enabled') {
          return $true
        } else {
          return $false
        }
      }

    }
    Set =
    {
      @("Microsoft-Windows-Subsystem-Linux","VirtualMachinePlatform").ForEach{
        Enable-WindowsOptionalFeature -Online -FeatureName $_ -NoRestart
        #Check for pending reboots
        if ($(Get-PendingReboot).RebootPending) {

        }
      }
    }
  },
  @{
    Describe = "Chocolatey is installed"
    Test = { if (-not (Get-Command docker | Out-Null))
      {
        return $false
      }
    }
    Set = {
      Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    }
  },
  @{
    Describe = "Docker is installed"
    Test = { if (-not (Get-Command docker | Out-Null))
      {
        return $false
      }
    }
    Set = {
    }
  }
  # @{
  #   Describe = "Resource 3 is present in the system"
  #   Test = { $mySystem -contains 3 }
  #   Set = {
  #     $mySystem.Add(3) | Out-Null
  #     Start-Sleep 1
  #   }
  # }
)

if (-not (Get-Command Invoke-Requirement -ErrorAction SilentlyContinue)) {
  Out-Host -InputObject "using this"
  Import-Module -Name "$PSScriptRoot\Requirements\Requirements.psd1" -Force -Verbose
}

$requirements | Invoke-Requirement | Format-Checklist
