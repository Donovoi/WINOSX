Import-Module .\WINOSX.psm1 -Force -Verbose

Import-RequiredModule -Name @("Requirements")

$requirements = @(
    @{
        Describe = "Resource 1 is present in the system"
        Test     = { $mySystem -contains 1 }
        Set      = {
            $mySystem.Add(1) | Out-Null
            Start-Sleep 1
        }
    },
    @{
        Describe = "Resource 2 is present in the system"
        Test     = { $mySystem -contains 2 }
        Set      = {
            $mySystem.Add(2) | Out-Null
            Start-Sleep 1
        }
    },
    @{
        Describe = "Resource 3 is present in the system"
        Test     = { $mySystem -contains 3 }
        Set      = {
            $mySystem.Add(3) | Out-Null
            Start-Sleep 1
        }
    }
)

$requirements | Invoke-Requirement