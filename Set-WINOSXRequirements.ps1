Import-Module .\WINOSX.psm1
Remove-Module -Name "$PSScriptRoot\Requirements\Requirements.psd1" -ErrorAction SilentlyContinue
#Import-RequiredModule -ModuleName @("$PSScriptRoot\Requirements\Requirements.psd1") -Verbose
Import-Module -Name "$PSScriptRoot\Requirements\Requirements.psd1"


$requirements = @(
  @{
    Describe = "Required features are enabled in Windows"
    Test =
    {
      #Check if Virtualzation is enabled in the BIOS
      
# Download the intel utitilty to check if virtualization is enabled
if (-Not (Test-Path -Path "$PSScriptRoot\Utilities")) {
  New-Item -Path "$PSScriptRoot\Utilities" -Type Directory -Force 
}
$ProgressPreference = 'SilentlyContinue'
Invoke-webrequest -URI "https://downloadmirror.intel.com/28539/Intel%20Processor%20Identification%20Utility.exe" -UseBasicParsing -OutFile "$PSScriptRoot\Utilities\IntelUtility.exe"
Out-Host -InputObject "Downloaded Intel Utility"
Out-Host -InputObject "Running Intel Utility to check if virtualization is enabled in the BIOS"
$IntelProcess = Start-Process -FilePath "$PSScriptRoot\Utilities\IntelUtility.exe"
#Stop-Process -Name $IntelProcess.Name -Force
#Remove-Item -Path "$PSScriptRoot\Utilities\IntelUtility.exe" -Force 


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
