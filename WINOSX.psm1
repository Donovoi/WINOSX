# Implement your module commands in this script.

#Either Import and install or simply import the specified module.
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
      Write-Output "$_"
    }

  }

}

#Show Toast notification - only compatible with powershell 5.1
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

#Make current running script admin
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

#Check for pending reboots
<#
***********************************************************************************
*   This function was written by Brian Wilhite
*   Published at https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
*	Version: 07/27/2015
*   Distributed according to Technet Terms of Use
*   https://technet.microsoft.com/en-us/cc300389.aspx
***********************************************************************************
#>
function Get-PendingReboot
{
<#
.SYNOPSIS
    Gets the pending reboot status on a local or remote computer.

.DESCRIPTION
    This function will query the registry on a local or remote computer and determine if the
    system is pending a reboot, from Microsoft updates, Configuration Manager Client SDK, Pending Computer
    Rename, Domain Join or Pending File Rename Operations. For Windows 2008+ the function will query the
    CBS registry key as another factor in determining pending reboot state.  "PendingFileRenameOperations"
    and "Auto Update\RebootRequired" are observed as being consistant across Windows Server 2003 & 2008.

    CBServicing = Component Based Servicing (Windows 2008+)
    WindowsUpdate = Windows Update / Auto Update (Windows 2003+)
    CCMClientSDK = SCCM 2012 Clients only (DetermineIfRebootPending method) otherwise $null value
    PendComputerRename = Detects either a computer rename or domain join operation (Windows 2003+)
    PendFileRename = PendingFileRenameOperations (Windows 2003+)
    PendFileRenVal = PendingFilerenameOperations registry value; used to filter if need be, some Anti-
                     Virus leverage this key for def/dat removal, giving a false positive PendingReboot

.PARAMETER ComputerName
    A single Computer or an array of computer names.  The default is localhost ($env:COMPUTERNAME).

.PARAMETER ErrorLog
    A single path to send error data to a log file.

.EXAMPLE
    PS C:\> Get-PendingReboot -ComputerName (Get-Content C:\ServerList.txt) | Format-Table -AutoSize

    Computer CBServicing WindowsUpdate CCMClientSDK PendFileRename PendFileRenVal RebootPending
    -------- ----------- ------------- ------------ -------------- -------------- -------------
    DC01           False         False                       False                        False
    DC02           False         False                       False                        False
    FS01           False         False                       False                        False

    This example will capture the contents of C:\ServerList.txt and query the pending reboot
    information from the systems contained in the file and display the output in a table. The
    null values are by design, since these systems do not have the SCCM 2012 client installed,
    nor was the PendingFileRenameOperations value populated.

.EXAMPLE
    PS C:\> Get-PendingReboot

    Computer           : WKS01
    CBServicing        : False
    WindowsUpdate      : True
    CCMClient          : False
    PendComputerRename : False
    PendFileRename     : False
    PendFileRenVal     :
    RebootPending      : True

    This example will query the local machine for pending reboot information.

.EXAMPLE
    PS C:\> $Servers = Get-Content C:\Servers.txt
    PS C:\> Get-PendingReboot -Computer $Servers | Export-Csv C:\PendingRebootReport.csv -NoTypeInformation

    This example will create a report that contains pending reboot information.

.LINK
    Component-Based Servicing:
    https://technet.microsoft.com/en-us/library/cc756291(v=WS.10).aspx

    PendingFileRename/Auto Update:
    https://support.microsoft.com/kb/2723674
    https://technet.microsoft.com/en-us/library/cc960241.aspx
    https://blogs.msdn.com/b/hansr/archive/2006/02/17/patchreboot.aspx

    SCCM 2012/CCM_ClientSDK:
    https://msdn.microsoft.com/en-us/library/jj902723.aspx

.NOTES
    Author:  Brian Wilhite
    Email:   bcwilhite (at) live.com
    Date:    29AUG2012
    PSVer:   2.0/3.0/4.0/5.0
    Updated: 27JUL2015
    UpdNote: Added Domain Join detection to PendComputerRename, does not detect Workgroup Join/Change
             Fixed Bug where a computer rename was not detected in 2008 R2 and above if a domain join occurred at the same time.
             Fixed Bug where the CBServicing wasn't detected on Windows 10 and/or Windows Server Technical Preview (2016)
             Added CCMClient property - Used with SCCM 2012 Clients only
             Added ValueFromPipelineByPropertyName=$true to the ComputerName Parameter
             Removed $Data variable from the PSObject - it is not needed
             Bug with the way CCMClientSDK returned null value if it was false
             Removed unneeded variables
             Added PendFileRenVal - Contents of the PendingFileRenameOperations Reg Entry
             Removed .Net Registry connection, replaced with WMI StdRegProv
             Added ComputerPendingRename
#>

  [CmdletBinding()]
  param(
    [Parameter(Position = 0,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [Alias("CN","Computer")]
    [String[]]$ComputerName = "$env:COMPUTERNAME",
    [string]$ErrorLog
  )

  begin {} ## End Begin Script Block
  process {
    foreach ($Computer in $ComputerName) {
      try {
        ## Setting pending values to false to cut down on the number of else statements
        $CompPendRen,$PendFileRename,$Pending,$SCCM = $false,$false,$false,$false

        ## Setting CBSRebootPend to null since not all versions of Windows has this value
        $CBSRebootPend = $null

        ## Querying WMI for build version
        $WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -Property BuildNumber,CSName -ComputerName $Computer -ErrorAction Stop

        ## Making registry connection to the local/remote computer
        $HKLM = [uint32]"0x80000002"
        $WMI_Reg = [wmiclass]"\\$Computer\root\default:StdRegProv"

        ## If Vista/2008 & Above query the CBS Reg Key
        if ([int32]$WMI_OS.BuildNumber -ge 6001) {
          $RegSubKeysCBS = $WMI_Reg.EnumKey($HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\")
          $CBSRebootPend = $RegSubKeysCBS.sNames -contains "RebootPending"
        }

        ## Query WUAU from the registry
        $RegWUAURebootReq = $WMI_Reg.EnumKey($HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\")
        $WUAURebootReq = $RegWUAURebootReq.sNames -contains "RebootRequired"

        ## Query PendingFileRenameOperations from the registry
        $RegSubKeySM = $WMI_Reg.GetMultiStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\Session Manager\","PendingFileRenameOperations")
        $RegValuePFRO = $RegSubKeySM.sValue

        ## Query JoinDomain key from the registry - These keys are present if pending a reboot from a domain join operation
        $Netlogon = $WMI_Reg.EnumKey($HKLM,"SYSTEM\CurrentControlSet\Services\Netlogon").sNames
        $PendDomJoin = ($Netlogon -contains 'JoinDomain') -or ($Netlogon -contains 'AvoidSpnSet')

        ## Query ComputerName and ActiveComputerName from the registry
        $ActCompNm = $WMI_Reg.GetStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName\","ComputerName")
        $CompNm = $WMI_Reg.GetStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName\","ComputerName")

        if (($ActCompNm -ne $CompNm) -or $PendDomJoin) {
          $CompPendRen = $true
        }

        ## If PendingFileRenameOperations has a value set $RegValuePFRO variable to $true
        if ($RegValuePFRO) {
          $PendFileRename = $true
        }

        ## Determine SCCM 2012 Client Reboot Pending Status
        ## To avoid nested 'if' statements and unneeded WMI calls to determine if the CCM_ClientUtilities class exist, setting EA = 0
        $CCMClientSDK = $null
        $CCMSplat = @{
          Namespace = 'ROOT\ccm\ClientSDK'
          Class = 'CCM_ClientUtilities'
          Name = 'DetermineIfRebootPending'
          ComputerName = $Computer
          ErrorAction = 'Stop'
        }
        ## Try CCMClientSDK
        try {
          $CCMClientSDK = Invoke-WmiMethod @CCMSplat
        } catch [System.UnauthorizedAccessException]{
          $CcmStatus = Get-Service -Name CcmExec -ComputerName $Computer -ErrorAction SilentlyContinue
          if ($CcmStatus.Status -ne 'Running') {
            Write-Warning "$Computer`: Error - CcmExec service is not running."
            $CCMClientSDK = $null
          }
        } catch {
          $CCMClientSDK = $null
        }

        if ($CCMClientSDK) {
          if ($CCMClientSDK.ReturnValue -ne 0) {
            Write-Warning "Error: DetermineIfRebootPending returned error code $($CCMClientSDK.ReturnValue)"
          }
          if ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending) {
            $SCCM = $true
          }
        }

        else {
          $SCCM = $null
        }

        ## Creating Custom PSObject and Select-Object Splat
        $SelectSplat = @{
          Property = (
            'Computer',
            'CBServicing',
            'WindowsUpdate',
            'CCMClientSDK',
            'PendComputerRename',
            'PendFileRename',
            'PendFileRenVal',
            'RebootPending'
          ) }
        New-Object -TypeName PSObject -Property @{
          Computer = $WMI_OS.CSName
          CBServicing = $CBSRebootPend
          WindowsUpdate = $WUAURebootReq
          CCMClientSDK = $SCCM
          PendComputerRename = $CompPendRen
          PendFileRename = $PendFileRename
          PendFileRenVal = $RegValuePFRO
          RebootPending = ($CompPendRen -or $CBSRebootPend -or $WUAURebootReq -or $SCCM -or $PendFileRename)
        } | Select-Object @SelectSplat

      } catch {
        Write-Warning "$Computer`: $_"
        ## If $ErrorLog, log the file to a user specified location/path
        if ($ErrorLog) {
          Out-File -InputObject "$Computer`,$_" -FilePath $ErrorLog -Append
        }
      }
    } ## End Foreach ($Computer in $ComputerName)
  } ## End Process

  end {} ## End End

} ## End Function Get-PendingReboot



#Run once reg key include this for reboots
Set-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name '!RegisterDNS' -Value "c:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe -noexit -command 'Register-DnsClient'"

# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function *-*
