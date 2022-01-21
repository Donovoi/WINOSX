Import-Module .\WINOSX.psm1 -Force -Verbose

Import-RequiredModule -Name @("Requirements")

$requirements = @(
  @{
    Describe = "WSL is enabled in Windows"
    Test =
    {
      $(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq 'Enabled'
    }
    Set =
    {
      Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
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
