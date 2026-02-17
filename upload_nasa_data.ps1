# Upload NASA ephemeris data to Docker VM via SSH key auth
# Destination: /mnt/truenas/planet-command/nasa_data/ on Docker VM (NFS-backed by TrueNAS)
# Uses SSH key auth (no password prompt)

$ErrorActionPreference = "Stop"

# --- Config ---
$DockerVmHost = "192.168.1.50"
$SshUser      = "bshaf"
$SshKey       = "$env:USERPROFILE\.ssh\claude_truenas"
$RemoteBase   = "/mnt/truenas/planet-command"
$RemoteDest   = "$RemoteBase/nasa_data"
$LocalSource  = "$PSScriptRoot\nasa_data"
$SshOpts      = @("-i", $SshKey)

# --- Validate local source ---
if (-not (Test-Path $LocalSource)) {
    Write-Host "ERROR: Local source not found: $LocalSource" -ForegroundColor Red
    exit 1
}

$fileCount = (Get-ChildItem -Path $LocalSource -Recurse -File).Count
$totalSize = (Get-ChildItem -Path $LocalSource -Recurse -File | Measure-Object -Property Length -Sum).Sum
$totalSizeGB = [math]::Round($totalSize / 1GB, 2)

Write-Host "=== NASA Data Upload ===" -ForegroundColor Cyan
Write-Host "Source:      $LocalSource"
Write-Host "Destination: ${SshUser}@${DockerVmHost}:${RemoteDest}"
Write-Host "Files:       $fileCount"
Write-Host "Total size:  ${totalSizeGB} GB"
Write-Host ""

# --- Create remote directory ---
Write-Host "Creating remote directory..." -ForegroundColor Yellow
ssh @SshOpts "${SshUser}@${DockerVmHost}" "sudo mkdir -p '$RemoteDest' && sudo chown ${SshUser}:${SshUser} '$RemoteDest'"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create remote directory. Check SSH access." -ForegroundColor Red
    exit 1
}

# --- Upload each subdirectory separately for progress tracking ---
$subdirs = Get-ChildItem -Path $LocalSource -Directory

foreach ($dir in $subdirs) {
    $dirSize = (Get-ChildItem -Path $dir.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $dirSizeDisplay = if ($dirSize -gt 1GB) { "$([math]::Round($dirSize / 1GB, 2)) GB" }
                      elseif ($dirSize -gt 1MB) { "$([math]::Round($dirSize / 1MB, 1)) MB" }
                      else { "$([math]::Round($dirSize / 1KB, 0)) KB" }
    $dirFiles = (Get-ChildItem -Path $dir.FullName -Recurse -File -ErrorAction SilentlyContinue).Count

    Write-Host ""
    Write-Host "Uploading $($dir.Name)/ ($dirFiles files, $dirSizeDisplay)..." -ForegroundColor Green
    scp @SshOpts -r "$($dir.FullName)" "${SshUser}@${DockerVmHost}:${RemoteDest}/"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: scp failed for $($dir.Name). You can re-run this script to retry." -ForegroundColor Yellow
    } else {
        Write-Host "  Done: $($dir.Name)" -ForegroundColor DarkGreen
    }
}

# --- Also upload any root-level files (scripts, etc.) ---
$rootFiles = Get-ChildItem -Path $LocalSource -File
if ($rootFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Uploading $($rootFiles.Count) root-level files..." -ForegroundColor Green
    foreach ($f in $rootFiles) {
        scp @SshOpts "$($f.FullName)" "${SshUser}@${DockerVmHost}:${RemoteDest}/"
    }
}

# --- Verify ---
Write-Host ""
Write-Host "=== Verifying upload ===" -ForegroundColor Cyan
ssh @SshOpts "${SshUser}@${DockerVmHost}" "du -sh '$RemoteDest'/*"

Write-Host ""
Write-Host "Upload complete! Files are at: ${DockerVmHost}:${RemoteDest}" -ForegroundColor Green
Write-Host "Files are on NFS-backed TrueNAS storage and persist across container rebuilds." -ForegroundColor DarkGray
