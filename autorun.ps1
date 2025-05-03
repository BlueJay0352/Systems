# PowerShell script for checking known autorun/startup persistance locations

# Check for admin and give user option to continue or exit
$admin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (! $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
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

}

else {
    Write-Host "Running as Administrator..." -ForegroundColor Green
    Start-Sleep -Seconds 1
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
    Write-Host "`n=== Registry Local Machine Autoruns ==="

    foreach ($entry in $machineRegEntries) {
        $path = $entry.Path
        $valueName = $entry.ValueName

        if (Test-Path $path) {
            # If valuename is present
            if ($null -ne $valueName) {
                Write-Host "`n[$path -> $valueName]" -ForegroundColor DarkCyan
                try {
                    $value = Get-ItemPropertyValue -Path $path -Name $valueName
                    Write-Host "${valueName}: $value" -ForegroundColor Yellow
                } catch {
                    Write-Host "Failed to get ${valueName}: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "`n[$path]" -ForegroundColor DarkCyan
                Get-ItemProperty -Path $path | ForEach-Object {
                    $_.PSObject.Properties | Where-Object {
                        $_.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")
                    } | ForEach-Object {
                        Write-Host "$($_.Name): $($_.Value)" -ForegroundColor Yellow
                    }
                }
            }
        } else {
            Write-Host "`n[$path]" -ForegroundColor Cyan    
            Write-Host "Path does not exist" -ForegroundColor Red
        }
    }
}

function Get-RegistryUserAutoruns {
    Write-Host "`n=== Registry User Autoruns ==="

    foreach ($entry in $userRegEntries) {

        # Get all user SIDs from HKEY_USERS
        $userSIDs = Get-ChildItem -Path "Registry::HKEY_USERS" | Where-Object {
            $_.Name -match '^HKEY_USERS\\S-\d-\d+-(\d+-){1,14}\d+$'
        }
    
        foreach ($sid in $userSIDs) {
            $sidString = ($sid.Name -replace '^HKEY_USERS\\', '')
            # Try to resolve SID to username
            try {
                $user = (New-Object System.Security.Principal.SecurityIdentifier($sidString)).Translate([System.Security.Principal.NTAccount]).Value
            } catch {
                $user = "UnknownUser"
            }
            
            # Construct full registry path with each sid name
            $fullPath = "Registry::$sid\$entry"
           
            if (Test-Path $fullPath) {
                Write-Host "`n[$user ($sidString)\$entry]" -ForegroundColor DarkCyan

                try {
                    Get-ItemProperty -Path $fullPath | ForEach-Object {
                        $_.PSObject.Properties | Where-Object {
                            $_.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")
                        } | ForEach-Object {
                            Write-Host "$($_.Name): $($_.Value)" -ForegroundColor Yellow
                        }
                    }
                } catch {
                    Write-Host "Failed to read values: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "`n[$user\$entry]" -ForegroundColor Cyan 
                Write-Host "Path does not exist" -ForegroundColor Red

            }
        }
    }
}
function Get-StartupFolderItems {
    $enabledUsers = Get-LocalUser | Where-Object { $_.Enabled -eq $true }

    $systemStartup = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"

    # Check system-wide startup folder
    Write-Host "`n=== System Startup Folder ==="
    if (Test-Path $systemStartup) {
        Write-Host "`n[$systemStartup]" -ForegroundColor DarkCyan
        Get-ChildItem -Path $systemStartup -Force | ForEach-Object {
            Write-Host $_.FullName -ForegroundColor Yellow
        }
    }

    # Loop through each enabled user's profile and check their Startup folder
    Write-Host "`n=== User Startup Folders ==="
    
    # Return path of windows users folder
    $usersLocation = ($env:SystemDrive + "\Users")
  
    foreach ($user in $enabledUsers) {
        $profilePath = "$usersLocation\$($user.Name)"
        $startupPath = Join-Path $profilePath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"

        if (Test-Path $startupPath) {
            Write-Host "`n[$startupPath]" -ForegroundColor DarkCyan
            Get-ChildItem -Path $startupPath -Force | ForEach-Object {
                Write-Host $_.FullName -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n[$startupPath] - Not found" -ForegroundColor Red
        }
    }
}
function Get-ScheduledTasks {
    Write-Host "`n=== Scheduled Tasks at Logon ==="`n
    $tasks = Get-ScheduledTask

    foreach ($task in $tasks) {
        $actions = ($task.Actions | ForEach-Object { $_.Execute + " " + $_.Arguments })
        Write-Host "Task: $($task.TaskName)" -ForegroundColor DarkCyan
        Write-Host "  Path: $($task.TaskPath)"
        Write-Host "  Actions: $actions"
    }
}

function Get-AutoStartServices {
    Write-Host "`n=== Auto-Start Services ==="`n
    Get-Service | Where-Object { $_.StartType -eq 'Automatic' } | ForEach-Object {
        Write-Host "$($_.Name): $($_.DisplayName)"
    }
}

function Get-WmicStartup {
    Write-Host "`n=== WMIC Startup Commands ==="`n
    try {
        $entries = wmic startup get Caption, Command
        $entries | Out-String
    } catch {
        Write-Host "WMIC not available on this system."
    }
}

# Execute All Checks
Get-RegistryLMAutoruns
Get-RegistryUserAutoruns
Get-StartupFolderItems
Get-ScheduledTasks
Get-AutoStartServices
Get-WmicStartup

if ($key.Key -eq "Enter") {
    Write-Host "=== Autorun scan using non admin credentials complete. ===" -ForegroundColor Green
} 
else {
    Write-Host "=== Autorun scan complete. ===" -ForegroundColor Green
}
