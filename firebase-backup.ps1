# ═══════════════════════════════════════════════════════
#  🔒 Firebase Realtime Database — Tägliches Backup
#  
#  Dieses Skript lädt die komplette Datenbank als JSON
#  herunter und speichert sie mit Datum im Dateinamen.
#  
#  EINRICHTUNG:
#  1. Die Variable $databaseURL unten anpassen
#  2. Den Backup-Ordner anpassen (Standard: Dokumente\FirebaseBackups)
#  3. Skript im Autostart ablegen:
#     - Win+R → shell:startup
#     - Verknüpfung erstellen zu diesem Skript
#     ODER
#     - Aufgabenplanung (taskschd.msc) → Neuer Task → Täglich
#
#  AUTOSTART-VERKNÜPFUNG:
#  Ziel: powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Pfad\zum\firebase-backup.ps1"
# ═══════════════════════════════════════════════════════

# ──── KONFIGURATION ────────────────────────────────────

# Deine Firebase Realtime Database URL (ohne Slash am Ende)
$databaseURL = "https://DEIN_PROJEKT-default-rtdb.europe-west1.firebasedatabase.app"

# Backup-Ordner (wird automatisch erstellt)
$backupFolder = "$env:USERPROFILE\Documents\FirebaseBackups"

# Alte Backups nach X Tagen löschen (0 = nie löschen)
$deleteAfterDays = 30

# ──── AB HIER NICHTS ÄNDERN ────────────────────────────

# Datum für Dateiname
$date = Get-Date -Format "yyyy-MM-dd_HHmm"
$fileName = "brettspiel-backup-$date.json"
$filePath = Join-Path $backupFolder $fileName

# Log-Funktion
function Write-Log {
    param([string]$Message)
    $logTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$logTime] $Message"
    Write-Host $logLine
    
    $logFile = Join-Path $backupFolder "backup-log.txt"
    Add-Content -Path $logFile -Value $logLine -ErrorAction SilentlyContinue
}

# Backup-Ordner erstellen
if (-not (Test-Path $backupFolder)) {
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
    Write-Log "Backup-Ordner erstellt: $backupFolder"
}

# Prüfen ob heute schon ein Backup existiert
$todayPattern = "brettspiel-backup-$(Get-Date -Format 'yyyy-MM-dd')*.json"
$existingToday = Get-ChildItem -Path $backupFolder -Filter $todayPattern -ErrorAction SilentlyContinue

if ($existingToday) {
    Write-Log "Backup für heute existiert bereits: $($existingToday.Name) — überspringe."
    exit 0
}

Write-Log "Starte Backup von $databaseURL ..."

try {
    # Datenbank herunterladen
    $url = "$databaseURL/.json"
    
    $response = Invoke-WebRequest -Uri $url -Method Get -ContentType "application/json" -UseBasicParsing
    
    if ($response.StatusCode -eq 200) {
        # JSON formatieren
        $jsonData = $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 100
        
        # Datei speichern (UTF-8 ohne BOM)
        [System.IO.File]::WriteAllText($filePath, $jsonData, [System.Text.UTF8Encoding]::new($false))
        
        $sizeKB = [math]::Round((Get-Item $filePath).Length / 1024, 1)
        Write-Log "Backup erfolgreich: $fileName ($sizeKB KB)"
    }
    else {
        Write-Log "FEHLER: HTTP Status $($response.StatusCode)"
        exit 1
    }
}
catch {
    Write-Log "FEHLER: $($_.Exception.Message)"
    exit 1
}

# Alte Backups aufräumen
if ($deleteAfterDays -gt 0) {
    $cutoff = (Get-Date).AddDays(-$deleteAfterDays)
    $oldFiles = Get-ChildItem -Path $backupFolder -Filter "brettspiel-backup-*.json" |
        Where-Object { $_.CreationTime -lt $cutoff }
    
    foreach ($file in $oldFiles) {
        Remove-Item $file.FullName -Force
        Write-Log "Altes Backup gelöscht: $($file.Name)"
    }
    
    if ($oldFiles.Count -gt 0) {
        Write-Log "$($oldFiles.Count) alte Backup(s) aufgeräumt (älter als $deleteAfterDays Tage)"
    }
}

# Zusammenfassung
$totalBackups = (Get-ChildItem -Path $backupFolder -Filter "brettspiel-backup-*.json").Count
$totalSizeMB = [math]::Round(
    (Get-ChildItem -Path $backupFolder -Filter "brettspiel-backup-*.json" |
        Measure-Object -Property Length -Sum).Sum / 1MB, 2
)
Write-Log "Gesamt: $totalBackups Backups ($totalSizeMB MB)"
Write-Log "Fertig."
