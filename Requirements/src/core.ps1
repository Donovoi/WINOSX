
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments","")]
param()

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\types.ps1"

$NamespaceDelimiter = ":"

# idempotently applies a requirement
function applyRequirement {
  [CmdletBinding()]
  param([Requirement]$Requirement)
  switch (("Test","Set" | Where-Object { $Requirement.$_ }) -join "-") {
    "Test" {
      [RequirementEvent]::new($Requirement,"Test","Start")
      $testResult = & $Requirement.Test
      [RequirementEvent]::new($Requirement,"Test","Stop",$testResult)
      if (-not $testResult) {
        Write-Error "Failed to apply Requirement '$($Requirement.Describe)'"
      }
    }
    "Set" {
      [RequirementEvent]::new($Requirement,"Set","Start")
      $setResult = & $Requirement.Set
      [RequirementEvent]::new($Requirement,"Set","Stop",$setResult)
    }
    "Test-Set" {
      [RequirementEvent]::new($Requirement,"Test","Start")
      $testResult = & $Requirement.Test
      [RequirementEvent]::new($Requirement,"Test","Stop",$testResult)
      if (-not $testResult) {
        [RequirementEvent]::new($Requirement,"Set","Start")
        $setResult = & $Requirement.Set
        [RequirementEvent]::new($Requirement,"Set","Stop",$setResult)
        [RequirementEvent]::new($Requirement,"Validate","Start")
        $validateResult = & $Requirement.Test
        [RequirementEvent]::new($Requirement,"Validate","Stop",$validateResult)
        if (-not $validateResult) {
          Write-Error "Failed to apply Requirement '$($Requirement.Describe)'"
        }
      }
    }
  }
}

# applies an array of requirements
function applyRequirements ([Requirement[]]$Requirements) {
  $Requirements | ForEach-Object { applyRequirement $_ }
}

# run the Test method of a requirement
function testRequirement ([Requirement]$Requirement) {
  if ($Requirement.Test) {
    [RequirementEvent]::new($Requirement,"Test","Start")
    $result = & $Requirement.Test
    [RequirementEvent]::new($Requirement,"Test","Stop",$result)
  }
}

# tests an array of requirements
function testRequirements ([Requirement[]]$Requirements) {
  $Requirements | ForEach-Object { testRequirement $_ }
}

# sorts an array of Requirements in topological order
function sortRequirements ([Requirement[]]$Requirements) {
  $stages = @()
  while ($Requirements) {
    $nextStages = $Requirements | Where-Object { -not ($_.DependsOn | Where-Object { $_ -notin $stages.Namespace }) }
    if (-not $nextStages) {
      throw "Could not resolve the dependencies for Requirements with names: $($Requirements.Namespace -join ', ')"
    }
    $Requirements = $Requirements | Where-Object { $_.Namespace -notin $nextStages.Namespace }
    $stages += $nextStages
  }
  $stages
}
