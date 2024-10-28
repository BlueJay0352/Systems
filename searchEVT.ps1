using namespace System.Collections.Generic

param (
    [string] $comps,
    [string] $evtID
)

$logHave = [List[String]]::new()
function isNum ($num) {
    return $num -match "^[\d\.]+$"
}

#Check for admin
$admin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (! $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Please run script as Administrator" -ForegroundColor Red
    Read-Host "Press any key to exit"
    exit 1
}
else {
    Write-Host "Running as Administrator..." -ForegroundColor Green
    Start-Sleep -Seconds 1
}

Do {
    $comps = $(Write-Host "Please Enter Computer Name or IP Address: " -ForegroundColor Green -NoNewline; Read-Host)
}
while ($comps -eq '')  
Do {
    $evtID = $(Write-Host "Please Enter Event ID to Search: " -ForegroundColor Green -NoNewline; Read-Host)
}
while (($evtID -eq '') -or (( -not(isNum $evtID))))

try {
    Write-Host "Testing Connectivity to $(($comps).ToUpper())"
    Test-Connection -ComputerName $comps -Count 1 -ErrorAction Stop | Out-Null
}
catch [System.Net.NetworkInformation.PingException] {
        Write-Host "The Computer $(($comps).ToUpper()) is not reachable" -ForegroundColor Red
        exit 1
}

$logsGet = Get-WinEvent -ListLog * -ComputerName $comps | Where-Object { $_.RecordCount } -ErrorAction Stop

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
    Write-Host "------ Found The Following Entries For EventID:" $evtID "------" -ForegroundColor White
    foreach ($channel in $logHave) {
        $entries = Get-WinEvent -FilterHashtable @{LogName=$channel.LogName;ID=$evtID}
        Write-Host $entries.Count $channel.LogName -ForegroundColor Green
    }
    $index = 0 
    foreach ($c in $logHave) {
        Write-Host "[$index] $($c.LogName)"
        $index++
    }
}