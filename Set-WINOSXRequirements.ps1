Import-Module .\WINOSX.psm1

Import-RequiredModule -ModuleName @("Requirements")

$requirements = @(
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
        Out-Host "Here"
      }
    }
  }
  #,
  # @{
  #   Describe = "Resource 2 is present in the system"
  #   Test = { $mySystem -contains 2 }
  #   Set = {
  #     $mySystem.Add(2) | Out-Null
  #     Start-Sleep 1
  #   }
  # },
  # @{
  #   Describe = "Resource 3 is present in the system"
  #   Test = { $mySystem -contains 3 }
  #   Set = {
  #     $mySystem.Add(3) | Out-Null
  #     Start-Sleep 1
  #   }
  # }
)

$requirements | Invoke-Requirement
