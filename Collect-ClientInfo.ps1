#Requires -Version 5.1
<#
.SYNOPSIS
    Sammelt Client-Informationen und speichert sie als JSON-Datei.
.DESCRIPTION
    Liest Hardware-, OS-, Netzwerk- und Software-Infos aus und schreibt
    sie in eine JSON-Datei im angegebenen Git-Repository-Ordner.
    Danach wird optional ein git commit + push ausgeführt.
.PARAMETER OutputPath
    Pfad zum "data"-Ordner im geklonten Git-Repository.
.PARAMETER AutoPush
    Wenn gesetzt, wird automatisch committed und gepusht.
#>
param(
    [string]$OutputPath = ".\data",
    [switch]$AutoPush
)

$ErrorActionPreference = "Stop"

# ── Daten sammeln ──────────────────────────────────────────────
$os      = Get-CimInstance Win32_OperatingSystem
$cs      = Get-CimInstance Win32_ComputerSystem
$cpu     = Get-CimInstance Win32_Processor | Select-Object -First 1
$bios    = Get-CimInstance Win32_BIOS
$disk    = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
$net     = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
$gpu     = Get-CimInstance Win32_VideoController | Select-Object -First 1
$uptime  = (Get-Date) - $os.LastBootUpTime

# RAM-Module
$ramModules = Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
    [PSCustomObject]@{
        Capacity_GB   = [math]::Round($_.Capacity / 1GB, 1)
        Speed_MHz     = $_.Speed
        Manufacturer  = $_.Manufacturer
    }
}

# Netzwerk-Adapter
$netAdapters = $net | ForEach-Object {
    [PSCustomObject]@{
        Description  = $_.Description
        MACAddress   = $_.MACAddress
        IPAddresses  = $_.IPAddress
        DHCPEnabled  = $_.DHCPEnabled
        DNSServers   = $_.DNSServerSearchOrder
        Gateway      = $_.DefaultIPGateway
    }
}

# Installierte Software (Top-Level)
$software = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                             "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } |
    Sort-Object DisplayName |
    ForEach-Object {
        [PSCustomObject]@{
            Name    = $_.DisplayName
            Version = $_.DisplayVersion
            Publisher = $_.Publisher
        }
    }

# Laufwerke
$drives = $disk | ForEach-Object {
    [PSCustomObject]@{
        Drive       = $_.DeviceID
        Label       = $_.VolumeName
        Size_GB     = [math]::Round($_.Size / 1GB, 1)
        Free_GB     = [math]::Round($_.FreeSpace / 1GB, 1)
        Used_Percent = [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 1)
    }
}

# ── JSON zusammenbauen ─────────────────────────────────────────
$clientInfo = [ordered]@{
    _meta = [ordered]@{
        collectedAt = (Get-Date -Format "o")
        scriptVersion = "1.1.0"
    }
    hostname    = $env:COMPUTERNAME
    domain      = $cs.Domain
    currentUser = "$env:USERDOMAIN\$env:USERNAME"
    os = [ordered]@{
        name         = $os.Caption
        version      = $os.Version
        build        = $os.BuildNumber
        architecture = $os.OSArchitecture
        installDate  = $os.InstallDate.ToString("o")
        lastBoot     = $os.LastBootUpTime.ToString("o")
        uptime       = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    }
    hardware = [ordered]@{
        manufacturer = $cs.Manufacturer
        model        = $cs.Model
        serial       = $bios.SerialNumber
        biosVersion  = $bios.SMBIOSBIOSVersion
        cpu = [ordered]@{
            name        = $cpu.Name.Trim()
            cores       = $cpu.NumberOfCores
            threads     = $cpu.NumberOfLogicalProcessors
            maxClock_MHz = $cpu.MaxClockSpeed
        }
        ram = [ordered]@{
            total_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
            modules  = $ramModules
        }
        gpu = [ordered]@{
            name       = $gpu.Name
            driver     = $gpu.DriverVersion
            vram_GB    = if ($gpu.AdapterRAM) { [math]::Round($gpu.AdapterRAM / 1GB, 1) } else { $null }
        }
    }
    storage  = $drives
    network  = $netAdapters
    software = $software
}

# ── Speichern ──────────────────────────────────────────────────
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }

$fileName = "$($env:COMPUTERNAME.ToLower()).json"
$filePath = Join-Path $OutputPath $fileName
$clientInfo | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8

Write-Host "✓ Gespeichert: $filePath" -ForegroundColor Green

# ── Optional: Git commit + push ────────────────────────────────
if ($AutoPush) {
    Push-Location (Split-Path $OutputPath)
    try {
        git add "data/$fileName"
        git commit -m "Update client info: $env:COMPUTERNAME - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git push
        Write-Host "✓ Git push erfolgreich" -ForegroundColor Green
    } catch {
        Write-Warning "Git push fehlgeschlagen: $_"
    } finally {
        Pop-Location
    }
}
