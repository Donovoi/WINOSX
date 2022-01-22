
$ErrorActionPreference = "Stop"

$RepoRoot = "$PSScriptRoot/.."
$SourceRoot = "$RepoRoot/src"
. "$SourceRoot\interface.ps1"

# Detect Admin on downlevel Powershell
$PlatformLacksDscSupport = $PSVersionTable.PSEdition -eq "Core"
if (-not $PlatformLacksDscSupport) {
  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $isAdmin = $identity.groups -match "S-1-5-32-544"
  if (-not $isAdmin) {
    throw @"
You are running PowerShell 5 and are therefore testing DSC resources.
You must be running as admin to test DSC resources.
"@
  }
}

Describe "New-Requirement" {
  Context "'Script' parameter set" {
    $requirement = @{
      Describe = "My Requirement"
      Test = { 1 }
      Set = { 2 }
    }
    It "Should not throw" {
      { New-Requirement @requirement } | Should -Not -Throw
    }
    It "Should not be empty" {
      New-Requirement @requirement | Should -BeTrue
    }
  }
  Context "'Dsc' parameter set" {
    It "Should not be empty" -Skip:$PlatformLacksDscSupport {
      $requirement = @{
        Describe = "My Dsc Requirement 1"
        ResourceName = "File"
        ModuleName = "PSDesiredStateConfiguration"
        Property = @{
          Contents = ""
          DestinationFile = ""
        }
      }
      New-Requirement @requirement | Should -BeTrue
    }
  }
}

Describe "Invoke-Requirement" {
  Context "Normal Requirement" {
    It "Should not error" {
      $requirement = @{
        Test = { 1 }
      }
      { Invoke-Requirement $requirement } | Should -Not -Throw
    }
  }
  Context "DSC Requirement" {
    It "Should apply the DSC resource" -Skip:$PlatformLacksDscSupport {
      $tempFilePath = "$env:TEMP\_dsctest_$(New-Guid).txt"
      $content = "Hello world"
      $params = @{
        Describe = "My Dsc Requirement 2"
        ModuleName = "PSDesiredStateConfiguration"
        ResourceName = "File"
        Property = @{
          Contents = $content
          DestinationPath = $tempFilePath
          Force = $true
        }
      }
      New-Requirement @params | Invoke-Requirement
      Get-Content $tempFilePath | Should -Be $content
      Remove-Item $tempFilePath
    }
  }
}

Describe "Test-Requirement" {
  It "Should not error" {
    $requirement = @{
      Test = { $true }
    }
    { Test-Requirement $requirement } | Should -Not -Throw
  }
  It "Should only emit 'Test' events" {
    $requirements = @(
      @{ Test = { $true } },
      @{ Set = { $true } }
    )
    $events = $requirements | Test-Requirement
    $events | ForEach-Object { $_.Method | Should -Be "Test" }
  }
}

Describe "Set-Requirement" {
  It "Should not error" {
    $requirement = @{
      Set = { $false }
    }
    { Invoke-Requirement $requirement } | Should -Not -Throw
  }
}

Describe "New-RequirementGroup" {
  It "Should prepend the namespace to the requirements" {
    $namespace = "MyReqs"
    $requirements = @(
      @{ Namespace = "req1" },
      @{ Namespace = "req2" }
    )

    New-RequirementGroup -Namespace $namespace -Requirement $requirements `
       | ForEach-Object { $_.Namespace | Should -BeLikeExactly "$namespace`:*" }
  }
  It "Should not contain multiple colons in a row" {
    $requirements = New-RequirementGroup "a" {
      New-RequirementGroup "b" {
        @{
          Describe = "1"
        }
        @{
          Describe = "2"
        }
      }
      @{
        Describe = "3"
      }
    }
    $requirements -join "|" | Should -Be "a:b>1|a:b>2|a>3"
  }
}
