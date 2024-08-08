
# Loading Function
function Show-Progress {
    param (
        [int]$Count,
        [string[]]$Colors
    )

    $colorIndex = 0

    for ($i = 1; $i -le $Count; $i++) {
        Write-Host "'." -ForegroundColor ($Colors[$colorIndex])
        Start-Sleep -Seconds 1
        $colorIndex = ($colorIndex + 1) % $Colors.Count
    }
}


$maxLength = 40

$ErrorActionPreference = "SilentlyContinue"







# Using auditpol to evaluate what policies are currently applied.
$output = AuditPol /Get /Category:*

# Initialise a hashtable
$auditData = @{}

# Split auditpol output into lines and use foreach loop to process each line using regex
$auditLines = $output -split "`n"
foreach ($line in $auditLines) {
    if ($line -match '^(\s*\S+(?: \S+)*)\s{2,}(.+)$') {
        $category = $matches[1].Trim()
        $setting = $matches[2].Trim()
        $auditData[$category] = $setting
    }
}




# Evid_Ref.csv contains the policy settings and EventIDs for security logs.
$csv = Import-Csv -Path ".\Evid_Ref.csv"




# UI
$BarsColourFG = "DarkBlue"
$BarsColourBG = "DarkCyan"
$MainHeadingColourFG = "DarkCyan"
$SubHeadingColour = "Gray"
$Desc = "White"
$LogoText_FG_Colour = "White"
$LogoText_BG_Colour = "DarkCyan"
$LogoColour = "White"
$CatColor = "Gray"
$EIDColor = "Yellow"
$logexportcolour = "Gray"
$ConfigLevelColour = "DarkCyan"
$PolicyColour = "White"



Clear
Start-Sleep -Seconds 1
Show-Progress -Count 7 -Colors @("red", "Green")
Clear



Write-Output "`n`n`n`n"





Write-Host "          ██╗  ██╗   ███████╗    ██████╗    " -ForegroundColor $LogoColour
Write-Host "          ██║  ██║   ██╔════╝   ██╔════╝    " -ForegroundColor $LogoColour -NoNewline; Write-Host "	Pre-Hunt Assessment"     -ForegroundColor $LogoText_FG_Colour -BackgroundColor $LogoText_BG_Colour
Write-Host "          ███████║   █████╗     ██║  ███╗   " -ForegroundColor $LogoColour -NoNewline; Write-Host "	Determine EventID Eligibility"  -ForegroundColor $LogoText_FG_Colour -BackgroundColor $LogoText_BG_Colour
Write-Host "          ██╔══██║   ██╔══╝     ██║   ██║   " -ForegroundColor $LogoColour -NoNewline; Write-Host "	Find and Understand Gaps in Logging Levels" -ForegroundColor $LogoText_FG_Colour -BackgroundColor $LogoText_BG_Colour
Write-Host "          ██║  ██║██╗███████╗██╗╚██████╔╝██╗" -ForegroundColor $LogoColour
Write-Host "          ╚═╝  ╚═╝╚═╝╚══════╝╚═╝ ╚═════╝ ╚═╝" -ForegroundColor $LogoColour



Write-Output "`n`n`n`n"

Start-Sleep -Seconds 1



Write-Host "    " -NoNewline; Write-Host "||||||" -ForegroundColor $BarsColourFG -BackgroundColor $BarsColourBG -NoNewline; Write-Host "  " -NoNewline;  Write-Host "CHECKING POWERSHELL LOGGING.`n`n" -ForegroundColor $MainHeadingColourFG



# Variables declared with 0 value. For each Get-Item below that returns true, the value in variable is incremented to 1.

$PowershellLogging = 0
$ModuleLogging = 0
$ScriptBlockLogging = 0


$moduleLoggingKey = Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames"
if ($moduleLoggingKey) {
    $ModuleLogging = 1
}


$scriptBlockLoggingKey = Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
if ($scriptBlockLoggingKey) {
    $ScriptBlockLogging = 1
}


# GPResult is checked. ForEach loop will check if any of Powershell Logging, Module Logging, Script Block return true. The value of variable is assigned at 1.

$gpresultOutput = gpresult /r
$powerShellLoggingInfo = $gpresultOutput | Select-String -Pattern "PowerShell Logging", "Module Logging", "Script Block Logging"



foreach ($line in $powerShellLoggingInfo) {
    if ($line -match "PowerShell Logging") {
        $PowershellLogging = 1
    }
    if ($line -match "Module Logging") {
        $ModuleLogging = 1
    }
    if ($line -match "Script Block Logging") {
        $ScriptBlockLogging = 1
    }
}


# If any of the previously declared variables have a value of 1, PowerShell is logging.

if ($PowershellLogging -eq 1 -or $ModuleLogging -eq 1 -or $ScriptBlockLogging -eq 1) {
    Write-Host "          Powershell logging is enabled." -ForegroundColor $SubHeadingColour
} else {
    Write-Host "          Powershell logging does not appear to be configured." -ForegroundColor $SubHeadingColour
}


Start-Sleep -Seconds 3


Write-Output "`n`n`n`n"


Start-Sleep -Seconds 1




Write-Host "    " -NoNewline; Write-Host "||||||" -ForegroundColor $BarsColourFG -BackgroundColor $BarsColourBG -NoNewline; Write-Host "  " -NoNewline; Write-Host "CHECKING SYSMON LOGGING." -ForegroundColor $MainHeadingColourFG -NoNewline; Write-Host "   (This process may take a few minutes)`n`n "  -ForegroundColor Red




# Variables declared with 0 value. For each 'Get-Cmdlet' below that returns true, the value in variable is incremented to 1.

$Process = 0
$Service = 0
$Registry = 0
$CIM = 0



$ProcessKey = Get-Process | Where-Object { $_.ProcessName -like "sysmon*" }
if ($ProcessKey){
    $Process = 1
}



$ServiceKey = Get-Service | Where-Object {($_.DisplayName -like "*sysmon*")}
if ($ServiceKey) {
    $Service = 1
}



$CIMKey = Get-CimInstance -ClassName Win32_Service | Where-Object { $_.Name -like 'Sysmon*' } 
if ($CIMKey) {
    $CIM = 1
}




$RegistryKey = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels' | Where-Object {($_.Name -like "*Sysmon*")}
if ($RegistryKey) {
    $Registry = 1
}



# Add the results from variables together.
$sysmonindicator = $Process + $Service + $Registry + $CIM




# If the results are equal to 2 or greater it can be assumed that Sysmon is running on system.
if ($sysmonindicator -ge 2) {
    Write-Host "          Sysmon logging is enabled." -ForegroundColor $SubHeadingColour
}


if ($sysmonindicator -lt 2) {
    Write-Host "          Sysmon logging does not appear to be configured." -ForegroundColor $SubHeadingColour
}







Start-Sleep -Seconds 3


Write-Output "`n`n`n`n"


Start-Sleep -Seconds 1







Write-Host "    " -NoNewline; Write-Host "||||||" -ForegroundColor $BarsColourFG -BackgroundColor $BarsColourBG -NoNewline; Write-Host "  " -NoNewline; Write-Host "CHECKING WINDOWS SECURITY LOGGING." -ForegroundColor $MainHeadingColourFG
Write-Output "`n`n`n"
Start-Sleep -Seconds 3

Write-Host "          * FULLY CONFIGURED:" -ForegroundColor $ConfigLevelColour -NoNewline; Write-Host "    All the below EventIDs are eligible to be recorded by this system." -ForegroundColor $Desc
Write-Output "`n`n"
Write-Host "              Policy" -ForegroundColor $PolicyColour -NoNewline; Write-Host "                                  EventID`n" -ForegroundColor $PolicyColour

# Iterate through the hashtable declared earlier and search for any cateogries that are equal to 'Success' AND 'Failure' - This means the policy is fully configured.
foreach ($key in $auditData.Keys) {
    if ($auditData[$key] -eq 'Success and Failure') {
        # Find the corresponding Policy/Eventid in the CSV file
        $category = $csv | Where-Object { $_.Category -eq $key } | Select-Object -First 1

        $keyFormatted = $key.PadRight($maxLength)  # Padding on $key to ensure EventIDs have a consistent placement on screen
       Write-Host "              $keyFormatted" -ForegroundColor $CatColor -NoNewline; Write-Host "$($category.Evid)" -ForegroundColor $EIDColor
    }
}


Start-Sleep -Seconds 3


Write-Output "`n`n`n`n"
Write-Host "          * PARTIALLY CONFIGURED:" -ForegroundColor $ConfigLevelColour -NoNewline; Write-Host "    Some of the below EventIDs are eligible to be recorded by this system." -ForegroundColor $Desc
Write-Output "`n`n"
Write-Host "              Policy" -ForegroundColor $PolicyColour -NoNewline; Write-Host "                                  EventID`n" -ForegroundColor $PolicyColour

# Iterate through the hashtable declared earlier and search for any cateogries that are equal to 'Success' OR 'Failure' - This means the policy is only partially configured.
foreach ($key in $auditData.Keys) {
    if ($auditData[$key] -eq 'Success'-or $auditData[$key] -eq 'Failure') {
        # Find the corresponding Policy/Eventid in the CSV file
        $category = $csv | Where-Object { $_.Category -eq $key } | Select-Object -First 1

        $keyFormatted = $key.PadRight($maxLength)
       Write-Host "              $keyFormatted" -ForegroundColor $CatColor -NoNewline; Write-Host "$($category.Evid)" -ForegroundColor $EIDColor
    }
}


Start-Sleep -Seconds 3

Write-Output "`n`n`n`n"
Write-Host "          * NOT CONFIGURED:" -ForegroundColor $ConfigLevelColour -NoNewline; Write-Host "    None of the below EventIDs are eligible to be recorded by this system." -ForegroundColor $Desc
Write-Output "`n`n"
Write-Host "              Policy" -ForegroundColor $PolicyColour -NoNewline; Write-Host "                                  EventID`n" -ForegroundColor $PolicyColour


# Iterate through the hashtable declared earlier and search for any cateogries that are equal to 'No Auditing' - This means the policy is not enabled/auditing.
foreach ($key in $auditData.Keys) {
    if ($auditData[$key] -eq 'No Auditing') {
        # Find the corresponding Policy/Eventid in the CSV file
        $category = $csv | Where-Object { $_.Category -eq $key } | Select-Object -First 1

       $keyFormatted = $key.PadRight($maxLength)
       Write-Host "              $keyFormatted" -ForegroundColor $CatColor -NoNewline; Write-Host "$($category.Evid)" -ForegroundColor $EIDColor
    }
}




Write-Output "`n`n`n`n"
