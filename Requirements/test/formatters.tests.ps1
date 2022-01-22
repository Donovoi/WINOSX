
$ErrorActionPreference = "Stop"

$RepoRoot = "$PSScriptRoot/.."
$SourceRoot = "$RepoRoot/src"
. "$SourceRoot\formatters.ps1"

function invoke ($Requirement) {
  [RequirementEvent]::new($Requirement,"Test","Start")
  [RequirementEvent]::new($Requirement,"Test","Stop",$false)
  [RequirementEvent]::new($Requirement,"Set","Start")
  [RequirementEvent]::new($Requirement,"Set","Stop",$true)
  [RequirementEvent]::new($Requirement,"Validate","Start")
  [RequirementEvent]::new($Requirement,"Validate","Stop",$true)
}

Describe "formatters" {
  $script:InDesiredState = 0
  $requirement = @{
    Namespace = "sr"
    Describe = "Simple Requirement"
    Test = { $script:InDesiredState++ }
    Set = {}
  }
  $events = invoke $requirement
  $tempContainer = $PSScriptRoot
  Context "Format-Table" {
    $output = $events | Format-Table | Out-String
    It "Should print a non-empty string" {
      $output.Trim().Length | Should -BeGreaterThan 10
    }
  }
  Context "Format-Checklist" {
    $path = "$tempContainer\$(New-Guid).txt"
    ($events | Format-Checklist) *> $path
    $output = Get-Content $path -Raw
    Remove-Item $path
    It "Should format each line as a checklist" {
      $output | Should -Match "^. \d\d:\d\d:\d\d\[sr|Simple Requirement"
    }
  }
  Context "Format-Verbose" {
    $path = "$tempContainer\$(New-Guid).txt"
    ($events | Format-Verbose) *> $path
    $output = Get-Content $path
    Remove-Item $path
    It "Should format each line" {
      $output | ForEach-Object { $_ | Should -Match "^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d +\w+ +\w+ .+" }
    }
    It "Should print 6 lines" {
      $output.count | Should -Be 6
    }
  }
}
