Import-Module .\WINOSX.psm1 -Force -Verbose

Import-RequiredModule -Name @("Requirements")

$requirements = @(
  @{
    Describe = "Required features are enabled in Windows"
    Test =
    {
      $RequiredFeatures = @("Microsoft-Windows-Subsystem-Linux","VirtualMachinePlatform")
      if ($(Get-WindowsOptionalFeature -Online -FeatureName $RequiredFeatures).State -eq 'Enabled') {
        return $true
      } else {
        return $false
      }

    }
    Set =
    {
      Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
    }
  },
  @{
    Describe = "Resource 2 is present in the system"
    Test = { $mySystem -contains 2 }
    Set = {
      $mySystem.Add(2) | Out-Null
      Start-Sleep 1
    }
  },
  @{
    Describe = "Resource 3 is present in the system"
    Test = { $mySystem -contains 3 }
    Set = {
      $mySystem.Add(3) | Out-Null
      Start-Sleep 1
    }
  }
)

$requirements | Invoke-Requirement
