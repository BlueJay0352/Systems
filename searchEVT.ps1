# PowerShell script for searching all Windows Event Logs for a specific EventID and Outputing to CSV

using namespace System.Collections.Generic

param (
    [string] $comp,
    [string] $evtID
)

# Declare arrays
$logHave = [List[String]]::new()
$entList = [List[String]]::new()

# Validate EventID is a Number
function isNum ($num) {
    return $num -match "^[\d\.]+$"
}

# Check for admin
$admin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (! $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Please run script as Administrator" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "Running as Administrator..." -ForegroundColor Green
    Start-Sleep -Seconds 1
}

# Prompt User For Input
Do {
    $comp = $(Write-Host "Please Enter Computer Name or IP Address " -ForegroundColor Green -NoNewline; Read-Host)
}
while ($comp -eq '')
Do {
    $evtID = $(Write-Host "Please Enter Event ID to Search: " -ForegroundColor Green -NoNewline; Read-Host)
}
while (($evtID -eq '') -or ( !(isNum $evtID)))


# Verify Connection To Computer
try {
    Write-Host "Testing Connectivity to $(($comp).ToUpper())"
    Test-Connection -ComputerName $comp -Count 1 -ErrorAction Stop | Out-Null
}
catch [System.Net.NetworkInformation.PingException] {
        Write-Host "The Computer $(($comp).ToUpper()) is not reachable" -ForegroundColor Red
        exit 1
}

# Only Get Logs With Records
$logsGet = Get-WinEvent -ListLog * -ComputerName $comp | Where-Object { $_.RecordCount } -ErrorAction Stop

#Loop Through Logs Searching For EventID
foreach ($log in $logsGet) {
    try {
        $rec = Get-WinEvent -FilterHashtable @{LogName=$log.LogName;ID=$evtID} -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($null -eq $rec) {
            Write-Warning "No Events found in $($log.Logname) for eventID $evtID."
        }  
        else {
            Write-Host "EventID:"$evtID "found in $($log.LogName)"
            $logHave += $log
        } 
    }
    catch { 
            Write-Error "Error Occured Retrieving Events from $($log.Logname): $_ "
    } 

}

if ($logHave.Count -eq 0) {
    Write-Host "------ No Entries Found For EventID:" $evtID "------" -ForegroundColor White
    exit 1
}  
else {
    Write-Host "------ Found The Following Entries For EventID:" $evtID "------"
    $index = 0 
    foreach ($channel in $logHave) {
        $entries = Get-WinEvent -FilterHashtable @{LogName=$channel.LogName;ID=$evtID}
        $entList += $entries.LogName.Count
        Write-Host [$index] $channel.LogName $entList[$index] "Events" -ForegroundColor Green
        $index++
    }

    $select = Read-Host "Enter the index of the entry you want to select (or press Enter to skip)"
    if ($select -ne "") {
        $selectedEntry = $logHave[$select]
        $fixLogName = $selectedEntry.LogName -replace '[\\/]', '_'
        $filePath = ".\$($fixLogName)_$evtID.csv"
        Write-Host "Selected: $($selectedEntry.LogName)"
        Get-WinEvent -FilterHashtable @{LogName=$selectedEntry.LogName;ID=$evtID} | Select-Object -Property TimeCreated, Id, ProviderName, MachineName, UserID, Message | Export-Csv -Path $filePath 
    # Export message column as one line       
        # Get-WinEvent -FilterHashtable @{LogName=$selectedEntry.LogName;ID=$evtID} | Select-Object -Property TimeCreated, Id, ProviderName, MachineName, UserID, @{n='Message';e={$_.Message -replace '\s+', " "}} | Export-Csv -Path $filePath 
        Write-Host "OutPut "$fixLogName'_'$evtID".csv to" $(pwd).Path -ForegroundColor Cyan
    }

}
