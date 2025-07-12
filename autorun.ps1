# PowerShell script for checking known autorun/startup persistance locations
# Outputs to file and compare last for any changes to these locations

# Check for admin and give user option to continue or exit
$admin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (! $isAdmin) {
    Write-Host "[!] Running script as Standard user, run as Administrator for best results " -ForegroundColor Red
    Write-Host "[!] Press Enter to continue without admin permissions, or Esc to exit..." -ForegroundColor Red
    $key = $null
    do {
        $key = [System.Console]::ReadKey($true)
        
        if ($key.Key -eq "escape") {
            Write-Host "`n[!] Aborting script...Goodbye" -ForegroundColor Red
            exit 
        }
    } until ($key.Key -eq 'Enter')
} else {
    Write-Host "Running as Administrator..." -ForegroundColor Green
    Start-Sleep -Seconds 2
}

# Get date and time add to filename
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outPath = "$env:USERPROFILE\Desktop\autorun-report_$timestamp.txt"

"===Windows AutoRun Report===" | Out-File -FilePath $outPath

if (!$isAdmin) {
    "===Script Run as Standard User===`n" | Tee-Object -Append -FilePath $outPath
} else {
    "===Script Run as Administrator===`n" | Tee-Object -Append -FilePath $outPath
}


# Windows Local Machine Registry - create hashtable array to eval both Path and ValueName
# https://www.picussecurity.com/resource/blog/picus-10-critical-mitre-attck-techniques-t1060-registry-run-keys-startup-folder
$machineRegEntries = @(
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" },
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" },
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" },
    @{ Path = "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run" },
    @{ Path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"; ValueName = "Userinit" },
    @{ Path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"; ValueName = "Shell" },
    @{ Path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"; ValueName = "Notify" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"; ValueName = "BootExecute" },
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" },
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" }
)

# Windows User Registry
$userRegEntries = @(
    "Software\Microsoft\Windows\CurrentVersion\Run",
    "Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
    "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
)

function Get-RegistryLMAutoruns {
    "`n=== Registry Local Machine Autoruns ===" | Tee-Object -Append -FilePath $outPath
    "`nIf you wish to remove a registry value see example below:" | Tee-Object -Append -FilePath $outPath
    "Remove-ItemProperty -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run\  -Name Adobe CCXProcess'" | Tee-Object -Append -FilePath $outPath

    foreach ($entry in $machineRegEntries) {
        $path = $entry.Path
        $valueName = $entry.ValueName

        if (Test-Path $path) {
            # If valuename is present
            if ($null -ne $valueName) {
                "`n[$path -> $valueName]" | Tee-Object -Append -FilePath $outPath
                try {
                    $value = Get-ItemPropertyValue -Path $path -Name $valueName
                    "${valueName}: $value" | Tee-Object -Append -FilePath $outPath
                } catch {
                    "Failed to get ${valueName}: $_" | Tee-Object -Append -FilePath $outPath
                } 
            } else {
                "`n[$path]" | Tee-Object -Append -FilePath $outPath
                Get-ItemProperty -Path $path | ForEach-Object {
                    $_.PSObject.Properties | Where-Object {
                        $_.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")
                    } | ForEach-Object {
                        "$($_.Name): $($_.Value)" | Tee-Object -Append -FilePath $outPath
                    }
                }
            }
        } else {
            "`n[$path]" | Tee-Object -Append -FilePath $outPath   
            "Path does not exist" | Tee-Object -Append -FilePath $outPath
        }
    }
}

function Get-RegistryUserAutoruns {
    "`n=== Registry User Autoruns ===" | Tee-Object -Append -FilePath $outPath

    foreach ($entry in $userRegEntries) {

        # Get all user SIDs from HKEY_USERS
        $userSIDs = Get-ChildItem -Path "Registry::HKEY_USERS" | Where-Object {
            $_.Name -match '^HKEY_USERS\\S-\d-\d+-(\d+-){1,14}\d+$'
        }
    
        # Resolve SID to username
        foreach ($sid in $userSIDs) {
            $sidString = ($sid.Name -replace '^HKEY_USERS\\', '')
            try {
                $user = (New-Object System.Security.Principal.SecurityIdentifier($sidString)).Translate([System.Security.Principal.NTAccount]).Value
            } catch {
                $user = "UnknownUser"
            }
            
            # Construct full registry path with each sid name
            $fullPath = "Registry::$sid\$entry"
           
            if (Test-Path $fullPath) {
                "`n[$user ($sidString)\$entry]" | Tee-Object -Append -FilePath $outPath

                try {
                    Get-ItemProperty -Path $fullPath | ForEach-Object {
                        $_.PSObject.Properties | Where-Object {
                            $_.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")
                        } | ForEach-Object {
                            "$($_.Name): $($_.Value)" | Tee-Object -Append -FilePath $outPath
                        }
                    }
                } catch {
                    "Failed to read values: $_" | Tee-Object -Append -FilePath $outPath
                }
            } else {
                "`n[$user\$entry]" | Tee-Object -Append -FilePath $outPath
                "Path does not exist" | Tee-Object -Append -FilePath $outPath

            }
        }
    }
}
function Get-StartupFolderItems {
    $enabledUsers = Get-LocalUser | Where-Object { $_.Enabled -eq $true }

    $systemStartup = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"

    # Check system-wide startup folder
    "`n=== System Startup Folder ===" | Tee-Object -Append -FilePath $outPath
    if (Test-Path $systemStartup) {
        "`n[$systemStartup]" | Tee-Object -Append -FilePath $outPath
        Get-ChildItem -Path $systemStartup -Force | ForEach-Object {
            $_.FullName | Tee-Object -Append -FilePath $outPath
        }
    }

    # Loop through each enabled user's profile and check their Startup folder
    "`n=== User Startup Folders ===" | Tee-Object -Append -FilePath $outPath
    
    # Return path of windows users folder
    $usersLocation = ($env:SystemDrive + "\Users")
  
    foreach ($user in $enabledUsers) {
        $profilePath = "$usersLocation\$($user.Name)"
        $startupPath = Join-Path $profilePath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"

        if (Test-Path $startupPath) {
            "`n[$startupPath]" | Tee-Object -Append -FilePath $outPath
            Get-ChildItem -Path $startupPath -Force | ForEach-Object {
                $_.FullName | Tee-Object -Append -FilePath $outPath
            }
        } else {
            "`n[$startupPath] - Not found" | Tee-Object -Append -FilePath $outPath
        }
    }
}
function Get-ScheduledTasks {
    "`n=== Scheduled Tasks at Logon ===`n" | Tee-Object -Append -FilePath $outPath
    $tasks = Get-ScheduledTask

    foreach ($task in $tasks) {
        $actions = ($task.Actions | ForEach-Object { $_.Execute + " " + $_.Arguments })
        "Task: $($task.TaskName)" | Tee-Object -Append -FilePath $outPath
        "  Path: $($task.TaskPath)" | Tee-Object -Append -FilePath $outPath
        "  Actions: $actions" | Tee-Object -Append -FilePath $outPath
    }
}

function Get-AutoStartServices {
    "`n=== Auto-Start Services ===`n" | Tee-Object -Append -FilePath $outPath
    Get-Service | Where-Object { $_.StartType -eq 'Automatic' } | ForEach-Object {
        "$($_.Name): $($_.DisplayName)" | Tee-Object -Append -FilePath $outPath
    }
}

function Get-WmicStartup {
    "`n=== WMIC Startup Commands ===`n" | Tee-Object -Append -FilePath $outPath
    try {
        # Deprecated - $entries = wmic startup get Caption, Command
        $entries = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command
        # Output as string to stop exec out of order
        $entries | Out-String | Tee-Object -Append -FilePath $outPath
    } catch {
        "WMIC not available on this system." | Tee-Object -Append -FilePath $outPath
    }
}

function Compare-Reports {

    $folderPath = "$env:USERPROFILE\Desktop"
    $filePattern = "autorun-report_*.txt"

    $files = Get-ChildItem -Path $folderPath -Filter $filePattern | Sort-Object LastWriteTime -Descending

    if ($files.Count -lt 2) {
        Write-Warning "Not enough files found to compare"
        return
    }

    # Get first 2 reports
    $latestFile = $files[0].FullName
    $previousFile = $files[1].FullName

    Write-Host "Comparing:`n - $latestFile`n - $previousFile`n"

    # Read contents into variables
    $contentLatest = Get-Content -Path $latestFile 
    $contentPrevious = Get-Content -Path $previousFile

    # Compare 2 files
    $changes = diff $contentLatest $contentPrevious 

    if ($changes) {
        Write-Host "`n!!!Differences found!!!" -ForegroundColor Red
        $changes | Format-Table
    } else {
        Write-Host "No differences found between the two reports" -ForegroundColor Green
    }
}

# Execute All Checks
Get-RegistryLMAutoruns
Get-RegistryUserAutoruns
Get-StartupFolderItems
Get-ScheduledTasks
Get-AutoStartServices
Get-WmicStartup

if (! $isAdmin) {
    Write-Host "=== Autorun scan using non admin credentials complete. ===" -ForegroundColor Green
} else {
    Write-Host "=== Autorun scan complete. ===" -ForegroundColor Green
}
Write-Host "Report Saved -" $outPath

Compare-Reports

