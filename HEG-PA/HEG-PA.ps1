
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







# Capture output
$output = AuditPol /Get /Category:*

# Initialise hashtable to store Category and Setting
$auditData = @{}

# Split output into lines and process each line using regex
$auditLines = $output -split "`n"
foreach ($line in $auditLines) {
    if ($line -match '^(\s*\S+(?: \S+)*)\s{2,}(.+)$') {
        $category = $matches[1].Trim()
        $setting = $matches[2].Trim()
        $auditData[$category] = $setting
    }
}




# Read CSV file into a PowerShell object
$csv = Import-Csv -Path ".\Evid_Ref.csv"




# UI
$BarsColourFG = "DarkBlue"
$BarsColourBG = "DarkCyan"

$MainHeadingColourFG = "DarkCyan"
#$MainHeadingColourBG = "Black"

$SubHeadingColour = "Gray"
$Desc = "White"


$LogoText_FG_Colour = "White"
$LogoText_BG_Colour = "DarkCyan"
$LogoColour = "White"


$LColor = 'Green'
$SColor = "magenta"
$TColor = "cyan"
$PColor = "white"

$CatColor = "Gray"
$EIDColor = "Yellow"
$logexportcolour = "Gray"

$ConfigLevelColour = "DarkCyan"




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



$PowershellLogging = 0
$ModuleLogging = 0
$ScriptBlockLogging = 0

# Module Logging Registry Key
$moduleLoggingKey = Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames"
if ($moduleLoggingKey) {
    $ModuleLogging = 1
}


#Script Block Logging Registry Key
$scriptBlockLoggingKey = Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
if ($scriptBlockLoggingKey) {
    $ScriptBlockLogging = 1
}




#Checking GPOs
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




if ($PowershellLogging -eq 1 -or $ModuleLogging -eq 1 -or $ScriptBlockLogging -eq 1) {
    Write-Host "          Powershell logging is enabled." -ForegroundColor $SubHeadingColour
} else {
    Write-Host "          Powershell logging does not appear to be configured." -ForegroundColor $SubHeadingColour
}


Start-Sleep -Seconds 3


Write-Output "`n`n`n`n"


Start-Sleep -Seconds 1




Write-Host "    " -NoNewline; Write-Host "||||||" -ForegroundColor $BarsColourFG -BackgroundColor $BarsColourBG -NoNewline; Write-Host "  " -NoNewline; Write-Host "CHECKING SYSMON LOGGING." -ForegroundColor $MainHeadingColourFG -NoNewline; Write-Host "   (This process may take a few minutes)`n`n "  -ForegroundColor Red



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




$sysmonindicator = $Process + $Service + $Registry + $CIM



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

Write-Host "          * FULLY CONFIGURED:`n" -ForegroundColor $ConfigLevelColour
Write-Host "              All the below Event IDs are eligible to be recorded by this system.`n" -ForegroundColor $Desc


# Iterate through the hashtable and search for any instances where $setting is equal to 'No Auditing'
foreach ($key in $auditData.Keys) {
    if ($auditData[$key] -eq 'Success and Failure') {
        # Find the corresponding 'Category' in the CSV file
        $category = $csv | Where-Object { $_.Category -eq $key } | Select-Object -First 1

        $keyFormatted = $key.PadRight($maxLength)  # Pad $key to ensure consistent length
       Write-Host "              $keyFormatted" -ForegroundColor $CatColor -NoNewline; Write-Host "$($category.Evid)" -ForegroundColor $EIDColor
    }
}


Start-Sleep -Seconds 3


Write-Output "`n`n`n`n"
Write-Host "          * PARTIALLY CONFIGURED:`n" -ForegroundColor $ConfigLevelColour 
Write-Host "              Some of the below Event IDs are eligible to be recorded by this system.`n" -ForegroundColor $Desc


# Iterate through the hashtable and search for any instances where $setting is equal to 'No Auditing'
foreach ($key in $auditData.Keys) {
    if ($auditData[$key] -eq 'Success'-or $auditData[$key] -eq 'Failure') {
        # Find the corresponding 'Category' in the CSV file
        $category = $csv | Where-Object { $_.Category -eq $key } | Select-Object -First 1

        $keyFormatted = $key.PadRight($maxLength)  # Pad $key to ensure consistent length
       Write-Host "              $keyFormatted" -ForegroundColor $CatColor -NoNewline; Write-Host "$($category.Evid)" -ForegroundColor $EIDColor
    }
}


Start-Sleep -Seconds 3

Write-Output "`n`n`n`n"
Write-Host "          * NOT CONFIGURED:`n" -ForegroundColor $ConfigLevelColour
Write-Host "              Not any of the below Event IDs are eligible to be recorded by this system.`n" -ForegroundColor $Desc


# Iterate through the hashtable and search for any instances where $setting is equal to 'No Auditing'
foreach ($key in $auditData.Keys) {
    if ($auditData[$key] -eq 'No Auditing') {
        # Find the corresponding 'Category' in the CSV file
        $category = $csv | Where-Object { $_.Category -eq $key } | Select-Object -First 1

       $keyFormatted = $key.PadRight($maxLength)  # Pad $key to ensure consistent length
       Write-Host "              $keyFormatted" -ForegroundColor $CatColor -NoNewline; Write-Host "$($category.Evid)" -ForegroundColor $EIDColor
    }
}




Write-Output "`n`n`n`n"
