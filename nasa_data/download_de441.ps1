# ============================================================================
# NASA JPL DE441 Ephemeris - Complete Data Downloader (PowerShell)
# ============================================================================
# Downloads all available DE441 planetary/lunar ephemeris data plus related
# satellite and small-body ephemerides from JPL's public FTP server.
#
# Estimated total: ~85 GB (all categories enabled)
#
# Features:
#   - Resume support (re-run safely after interruption)
#   - Organized subdirectories by data type
#   - Progress tracking with running totals
#   - Configurable: enable/disable categories via flags below
#
# Usage:
#   .\download_de441.ps1
#
# To download only specific categories, edit the $Download* flags below.
# ============================================================================

#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# ---- Configuration: toggle categories on/off ----
$DownloadBSP         = $true   # DE441 binary SPK file (~3.1 GB)
$DownloadASCII       = $true   # DE441 ASCII coefficients (~8.8 GB)
$DownloadLinux       = $true   # DE441 Linux binary (~2.6 GB)
$DownloadNIO         = $true   # DE441 NIO format (~3.3 GB)
$DownloadSmallBodies = $false   # Asteroid perturbers for DE441 (~15.7 GB)
$DownloadSatellites  = $false   # All satellite ephemerides (~50 GB)
$DownloadBPC         = $true   # Lunar orientation frames (~13 MB)
$DownloadDocs        = $true   # IOMs, papers, Fortran readers (~30 MB)
$DownloadTestData    = $true   # Verification test data (~10 MB)

# ---- Base URLs ----
$Base    = "https://ssd.jpl.nasa.gov/ftp/eph"
$Planets = "$Base/planets"

# ---- Output directory (script's location) ----
$Out = $PSScriptRoot
if (-not $Out) { $Out = (Get-Location).Path }

# ---- Counters ----
$script:TotalFiles      = 0
$script:SkippedFiles    = 0
$script:DownloadedFiles = 0
$script:FailedFiles     = 0

# ---- Utility: format bytes ----
function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

# ---- Download helper ----
# Streams downloads with resume support. Always shows a progress bar —
# percentage-based when Content-Length is known, bytes-only when unknown.
function Download-File {
    param(
        [string]$Url,
        [string]$Dest
    )

    $script:TotalFiles++

    # Create parent directory
    $dir = Split-Path -Parent $Dest
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $fileName = Split-Path -Leaf $Dest

    # Check if file exists and get remote size for skip detection
    $resumeOffset = 0
    if (Test-Path $Dest) {
        $localSize = (Get-Item $Dest).Length
        try {
            $headReq = [System.Net.HttpWebRequest]::Create($Url)
            $headReq.Method = "HEAD"
            $headReq.Timeout = 30000
            $headReq.AllowAutoRedirect = $true
            $headResp = $headReq.GetResponse()
            $remoteSize = $headResp.ContentLength
            $headResp.Close()
            $headResp = $null

            if ($remoteSize -gt 0 -and $localSize -ge $remoteSize) {
                Write-Host "  [SKIP] $fileName (already complete)" -ForegroundColor DarkGray
                $script:SkippedFiles++
                return
            }
        }
        catch {
            # HEAD failed, try downloading anyway
        }
        $resumeOffset = $localSize
    }

    Write-Host "  [GET]  $fileName" -ForegroundColor Cyan

    $maxRetries = 5
    $retryDelay = 10
    $success = $false
    $fileStream = $null
    $stream = $null
    $resp = $null

    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            # Re-check offset in case a prior attempt wrote partial data
            if (Test-Path $Dest) {
                $resumeOffset = (Get-Item $Dest).Length
            }

            $req = [System.Net.HttpWebRequest]::Create($Url)
            $req.Timeout = 300000        # 5 min connect timeout
            $req.ReadWriteTimeout = 600000  # 10 min read timeout

            if ($resumeOffset -gt 0) {
                $req.AddRange($resumeOffset)
            }

            try {
                $resp = $req.GetResponse()
            }
            catch [System.Net.WebException] {
                if ($_.Exception.Response -and
                    $_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::RequestedRangeNotSatisfiable) {
                    # 416 = file already complete
                    Write-Host "  [SKIP] $fileName (already complete)" -ForegroundColor DarkGray
                    $script:SkippedFiles++
                    $script:TotalFiles--
                    return
                }
                throw
            }

            $stream = $resp.GetResponseStream()
            $remainingBytes = $resp.ContentLength          # bytes still to download (-1 if unknown)
            $totalExpected = if ($remainingBytes -gt 0) { $remainingBytes + $resumeOffset } else { -1 }
            $knowsTotal = ($totalExpected -gt 0)

            if ($resumeOffset -gt 0) {
                $fileStream = [System.IO.File]::Open($Dest, [System.IO.FileMode]::Append)
            }
            else {
                $fileStream = [System.IO.File]::Create($Dest)
            }

            $buffer = New-Object byte[] 1048576  # 1 MB buffer
            $totalRead = $resumeOffset
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $fileStream.Write($buffer, 0, $read)
                $totalRead += $read

                # Calculate speed
                $elapsedSec = $stopwatch.Elapsed.TotalSeconds
                $speed = if ($elapsedSec -gt 0) { ($totalRead - $resumeOffset) / $elapsedSec } else { 0 }
                $speedStr = if ($speed -ge 1MB) { "{0:N1} MB/s" -f ($speed / 1MB) }
                           elseif ($speed -ge 1KB) { "{0:N0} KB/s" -f ($speed / 1KB) }
                           else { "{0:N0} B/s" -f $speed }

                if ($knowsTotal) {
                    $pct = [math]::Round(($totalRead / $totalExpected) * 100, 1)
                    $pctClamped = [math]::Min($pct, 100)
                    Write-Progress -Activity "Downloading $fileName" `
                        -Status ("$(Format-Size $totalRead) / $(Format-Size $totalExpected)  ($pct%)  $speedStr") `
                        -PercentComplete $pctClamped `
                        -Id 1
                }
                else {
                    # Unknown total — show indeterminate progress (cycles 0-100)
                    $fakePct = [int](($totalRead / 1MB) % 100)
                    Write-Progress -Activity "Downloading $fileName" `
                        -Status ("$(Format-Size $totalRead) downloaded  $speedStr") `
                        -PercentComplete $fakePct `
                        -Id 1
                }
            }

            $stopwatch.Stop()
            $fileStream.Close(); $fileStream = $null
            $stream.Close(); $stream = $null
            $resp.Close(); $resp = $null
            Write-Progress -Activity "Downloading $fileName" -Completed -Id 1

            $finalSize = Format-Size $totalRead
            $avgSpeed = if ($stopwatch.Elapsed.TotalSeconds -gt 0) {
                $s = ($totalRead - $resumeOffset) / $stopwatch.Elapsed.TotalSeconds
                if ($s -ge 1MB) { "{0:N1} MB/s" -f ($s / 1MB) }
                elseif ($s -ge 1KB) { "{0:N0} KB/s" -f ($s / 1KB) }
                else { "{0:N0} B/s" -f $s }
            } else { "---" }
            Write-Host "  [DONE] $fileName  ($finalSize @ $avgSpeed)" -ForegroundColor Green

            $success = $true
            break
        }
        catch {
            Write-Progress -Activity "Downloading $fileName" -Completed -Id 1
            if ($attempt -lt $maxRetries) {
                Write-Host "  [RETRY] $fileName - attempt $attempt/$maxRetries ($($_.Exception.Message))" -ForegroundColor Yellow
                Start-Sleep -Seconds $retryDelay
            }
            else {
                Write-Host "  [FAIL] $fileName - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        finally {
            if ($fileStream) { $fileStream.Dispose(); $fileStream = $null }
            if ($stream) { $stream.Dispose(); $stream = $null }
            if ($resp) { $resp.Close(); $resp = $null }
        }
    }

    if ($success) {
        $script:DownloadedFiles++
    }
    else {
        $script:FailedFiles++
    }
}

# Force TLS 1.2 (required by many HTTPS servers)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

Write-Host "============================================================" -ForegroundColor White
Write-Host "  NASA JPL DE441 Ephemeris Downloader (PowerShell)" -ForegroundColor Green
Write-Host "  Output: $Out" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White
Write-Host ""

# ============================================================================
# 1. DE441 Binary SPK (SPICE kernel) — ~3.1 GB
# ============================================================================
if ($DownloadBSP) {
    Write-Host ">>> [1/9] DE441 Binary SPK (~3.1 GB)" -ForegroundColor Yellow
    Download-File "$Planets/bsp/de441.bsp"   "$Out\bsp\de441.bsp"
    Download-File "$Planets/bsp/de440.bsp"   "$Out\bsp\de440.bsp"
    Download-File "$Planets/bsp/de440s.bsp"  "$Out\bsp\de440s.bsp"
    Download-File "$Planets/bsp/README.txt"  "$Out\bsp\README.txt"
    Write-Host ""
}

# ============================================================================
# 2. DE441 ASCII Chebyshev Coefficients — ~8.8 GB (31 files)
# ============================================================================
if ($DownloadASCII) {
    Write-Host ">>> [2/9] DE441 ASCII coefficients (~8.8 GB)" -ForegroundColor Yellow
    Download-File "$Planets/ascii/de441/header.441" "$Out\ascii\header.441"
    Download-File "$Planets/ascii/de441/testpo.441" "$Out\ascii\testpo.441"

    # Negative millennia: ascm01000 through ascm13000
    for ($i = 1000; $i -le 13000; $i += 1000) {
        $padded = $i.ToString("D5")
        Download-File "$Planets/ascii/de441/ascm$padded.441" "$Out\ascii\ascm$padded.441"
    }

    # Positive millennia: ascp00000 through ascp16000
    for ($i = 0; $i -le 16000; $i += 1000) {
        $padded = $i.ToString("D5")
        Download-File "$Planets/ascii/de441/ascp$padded.441" "$Out\ascii\ascp$padded.441"
    }
    Write-Host ""
}

# ============================================================================
# 3. DE441 Linux Binary — ~2.6 GB
# ============================================================================
if ($DownloadLinux) {
    Write-Host ">>> [3/9] DE441 Linux binary (~2.6 GB)" -ForegroundColor Yellow
    Download-File "$Planets/Linux/de441/linux_m13000p17000.441" "$Out\linux\linux_m13000p17000.441"
    Download-File "$Planets/Linux/de441/header.441"              "$Out\linux\header.441"
    Download-File "$Planets/Linux/de441/testpo.441"              "$Out\linux\testpo.441"
    Write-Host ""
}

# ============================================================================
# 4. DE441 NIO Format — ~3.3 GB
# ============================================================================
if ($DownloadNIO) {
    Write-Host ">>> [4/9] DE441 NIO format (~3.3 GB)" -ForegroundColor Yellow
    Download-File "$Planets/nio/de441.ftp"  "$Out\nio\de441.ftp"
    Download-File "$Planets/nio/README.txt" "$Out\nio\README.txt"
    Write-Host ""
}

# ============================================================================
# 5. Small Bodies (Asteroid Perturbers for DE441) — ~15.7 GB
# ============================================================================
if ($DownloadSmallBodies) {
    Write-Host ">>> [5/9] Small body ephemerides (~15.7 GB)" -ForegroundColor Yellow
    Download-File "$Base/small_bodies/asteroids_de441/sb441-n16.bsp"                       "$Out\small_bodies\sb441-n16.bsp"
    Download-File "$Base/small_bodies/asteroids_de441/sb441-n373.bsp"                      "$Out\small_bodies\sb441-n373.bsp"
    Download-File "$Base/small_bodies/asteroids_de441/sb441-n373s.bsp"                     "$Out\small_bodies\sb441-n373s.bsp"
    Download-File "$Base/small_bodies/asteroids_de441/SB441_IOM392R-21-005_perturbers.pdf" "$Out\small_bodies\SB441_IOM392R-21-005_perturbers.pdf"
    Write-Host ""
}

# ============================================================================
# 6. Satellite Ephemerides (all planets) — ~50 GB
# ============================================================================
if ($DownloadSatellites) {
    Write-Host ">>> [6/9] Satellite ephemerides (~50 GB)" -ForegroundColor Yellow
    $SatBsp = "$Base/satellites/bsp"

    # -- Jupiter system --
    Write-Host "    Jupiter moons..." -ForegroundColor DarkCyan
    $jupiterFiles = @(
        "jup340.bsp", "jup341.bsp", "jup343.bsp", "jup344.bsp", "jup345.bsp",
        "jup346.bsp", "jup347.bsp", "jup357.bsp", "jup357_1600.bsp", "jup363.bsp",
        "jup365.bsp", "jup380s.bsp", "jup387.2021_2400.bsp", "jup387xl.bsp"
    )
    foreach ($f in $jupiterFiles) {
        Download-File "$SatBsp/$f" "$Out\satellites\$f"
    }

    # -- Mars system --
    Write-Host "    Mars moons..." -ForegroundColor DarkCyan
    $marsFiles = @("mar097.bsp", "mar097.2100-2500.bsp", "mar099.bsp")
    foreach ($f in $marsFiles) {
        Download-File "$SatBsp/$f" "$Out\satellites\$f"
    }

    # -- Saturn system --
    Write-Host "    Saturn moons..." -ForegroundColor DarkCyan
    $saturnFiles = @(
        "sat360xl.bsp", "sat427l.bsp", "sat428.bsp", "sat440l.bsp", "sat441l.bsp",
        "sat441xl.back.bsp", "sat441xl.fwrd.bsp", "sat450.bsp", "sat452.bsp",
        "sat453.bsp", "sat454.bsp", "sat455.bsp", "sat456.bsp", "sat457.bsp",
        "sat143.bsp", "daphnis.sat393.bsp"
    )
    foreach ($f in $saturnFiles) {
        Download-File "$SatBsp/$f" "$Out\satellites\$f"
    }

    # -- Neptune system --
    Write-Host "    Neptune moons..." -ForegroundColor DarkCyan
    $neptuneFiles = @(
        "nep090.bsp", "nep096.bsp", "nep097.bsp", "nep100.bsp", "nep101.bsp",
        "nep101.30kyr.bsp", "nep102.bsp", "nep103.bsp", "nep104.bsp", "nep105.bsp",
        "Triton.nep097.30kyr.bsp"
    )
    foreach ($f in $neptuneFiles) {
        Download-File "$SatBsp/$f" "$Out\satellites\$f"
    }

    # -- Uranus system --
    Write-Host "    Uranus moons..." -ForegroundColor DarkCyan
    $uranusFiles = @(
        "ura111.bsp", "ura111.30kyr.bsp", "ura111.xl.bsp", "ura115.bsp",
        "ura116.bsp", "ura116.30kyr.bsp", "ura117.bsp", "ura155.bsp",
        "ura158.bsp", "ura159.bsp", "ura160.bsp", "ura161.bsp", "ura167.bsp",
        "ura178.bsp", "ura182.bsp", "ura183.bsp", "ura184.bsp"
    )
    foreach ($f in $uranusFiles) {
        Download-File "$SatBsp/$f" "$Out\satellites\$f"
    }

    # -- Pluto system --
    Write-Host "    Pluto moons..." -ForegroundColor DarkCyan
    $plutoFiles = @("plu022.bsp", "plu043.bsp", "plu049.bsp", "plu055.bsp", "plu058.bsp", "plu060.bsp")
    foreach ($f in $plutoFiles) {
        Download-File "$SatBsp/$f" "$Out\satellites\$f"
    }

    # -- TNO satellites --
    Write-Host "    TNO satellites..." -ForegroundColor DarkCyan
    $tnoFiles = @(
        "tnosat_v001_20000617_jpl082_20230601.bsp",
        "tnosat_v001_20050000_jpl043_20220908.bsp",
        "tnosat_v001_20090482_jpl043_20220908.bsp",
        "tnosat_v001_20120347_jpl025_20220908.bsp",
        "tnosat_v001_20136108_jpl110_20220908.bsp",
        "tnosat_v001_20136199_jpl080_20220908.bsp",
        "tnosat_v001_20469705_jpl009_20220908.bsp",
        "tnosat_v001_20612095_jpl006_20220908.bsp",
        "tnosat_v001_20612687_jpl008_20220908.bsp",
        "tnosat_v001_53031823_jpl010_20220908.bsp",
        "tnosat_v001_53092511_jpl005_20220908.bsp",
        "tnosat_v001b_20136108_jpl110_20221014.bsp"
    )
    foreach ($f in $tnoFiles) {
        Download-File "$SatBsp/$f" "$Out\satellites\$f"
    }

    # -- Approach ephemerides --
    Write-Host "    Approach ephemerides..." -ForegroundColor DarkCyan
    $approachFiles = @(
        "130412AP_RE_90165_18018.bsp", "130528BP_IRRE_00256_25017.bsp",
        "140127AP_RE_90165_18018.bsp", "140809BP_IRRE_00256_25017.bsp",
        "150422AP_RE_90165_18018.bsp", "150720AP_RE_90165_18018.bsp",
        "161011AP_RE_90165_18018.bsp", "161101AP_RE_90165_18018.bsp",
        "180927AP_RE_90165_18018.bsp", "20000617.bsp",
        "se_jup342.bsp", "se_pluto058.xl.bsp"
    )
    foreach ($f in $approachFiles) {
        Download-File "$SatBsp/$f" "$Out\satellites\$f"
    }

    # -- Log files --
    $logFiles = @(
        "jup345.spk.log", "jup346.spk.log", "jup347.log", "jup380s.log",
        "jup365.spk.txt", "mar099.spk.log", "sat441l.log", "sat450.spk.txt",
        "sat452.log", "sat453.log", "sat454.log", "sat455.log", "sat456.log",
        "sat457.log", "ura117.spk.log", "ura182.log", "ura183.log", "ura184.log",
        "plu060.spk.log", "plu060.spk.tex", "nep102.spk.log", "nep103.spk.log",
        "nep104.spk.log", "nep105.log"
    )
    foreach ($f in $logFiles) {
        Download-File "$SatBsp/$f" "$Out\satellites\$f"
    }
    Write-Host ""
}

# ============================================================================
# 7. Lunar Frame Kernels (BPC) — ~13 MB
# ============================================================================
if ($DownloadBPC) {
    Write-Host ">>> [7/9] Lunar orientation frames (~13 MB)" -ForegroundColor Yellow
    Download-File "$Planets/bpc/README.txt"                  "$Out\bpc\README.txt"
    Download-File "$Planets/bpc/moon_190627.tf"              "$Out\bpc\moon_190627.tf"
    Download-File "$Planets/bpc/moon_pa_de430_1550-2650.bpc" "$Out\bpc\moon_pa_de430_1550-2650.bpc"
    Write-Host ""
}

# ============================================================================
# 8. Documentation (IOMs, papers, Fortran source) — ~30 MB
# ============================================================================
if ($DownloadDocs) {
    Write-Host ">>> [8/9] Documentation & tools (~30 MB)" -ForegroundColor Yellow

    # IOMs and papers
    $iomFiles = @(
        "ExplSupplChap8.pdf", "LLR_Model_2020_DR.pdf", "de403.iom.pdf",
        "de405.iom.pdf", "de405_for_Mars_Surveyor_01nov2000.pdf", "de409.iom.pdf",
        "de410.iom.pdf", "de414.iom.pdf", "de418.iom.v3.pdf", "de421.iom.v1.pdf",
        "de421_moon_coord_iom.pdf", "de423.iom.pdf", "de424.iom.pdf",
        "de430_moon_coord_iom.pdf", "de432.pluto.05may2014.pdf", "de434.iom.pdf",
        "de435.iom.pdf", "de440.aj.pdf"
    )
    foreach ($f in $iomFiles) {
        Download-File "$Planets/ioms/$f" "$Out\docs\$f"
    }

    # DE440/441 overview paper
    Download-File "https://ssd.jpl.nasa.gov/doc/Park.2021.AJ.DE440.pdf" "$Out\docs\Park.2021.AJ.DE440.pdf"

    # Top-level READMEs
    Download-File "$Planets/README.txt"        "$Out\docs\planets_README.txt"
    Download-File "$Planets/CDROM.notes"       "$Out\docs\CDROM.notes"
    Download-File "$Planets/other_readers.txt" "$Out\docs\other_readers.txt"

    # Fortran source for reading ephemerides
    $fortranFiles = @("README.txt", "asc2eph.f", "testeph.f", "testeph1.f", "userguide.txt")
    foreach ($f in $fortranFiles) {
        Download-File "$Planets/fortran/$f" "$Out\fortran\$f"
    }
    Write-Host ""
}

# ============================================================================
# 9. Test / Verification Data — ~10 MB
# ============================================================================
if ($DownloadTestData) {
    Write-Host ">>> [9/9] Test & verification data (~10 MB)" -ForegroundColor Yellow
    $testFiles = @(
        "testpo.102.gz", "testpo.200", "testpo.202", "testpo.403", "testpo.405",
        "testpo.406", "testpo.410", "testpo.413", "testpo.414", "testpo.418",
        "testpo.421", "testpo.421x", "testpo.422", "testpo.423"
    )
    foreach ($f in $testFiles) {
        Download-File "$Planets/test-data/$f" "$Out\test_data\$f"
    }
    Write-Host ""
}

# ============================================================================
# Summary
# ============================================================================
Write-Host "============================================================" -ForegroundColor White
Write-Host "  Download Complete" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor White
Write-Host "  Total files:      $($script:TotalFiles)"
Write-Host "  Downloaded:       $($script:DownloadedFiles)" -ForegroundColor Green
Write-Host "  Skipped (exist):  $($script:SkippedFiles)" -ForegroundColor DarkGray
Write-Host "  Failed:           $($script:FailedFiles)" -ForegroundColor $(if ($script:FailedFiles -gt 0) { "Red" } else { "Green" })
Write-Host ""
Write-Host "  Location: $Out"
Write-Host ""

# Show disk usage per subdirectory
Write-Host "  Disk usage:" -ForegroundColor White
$subdirs = Get-ChildItem -Path $Out -Directory -ErrorAction SilentlyContinue
foreach ($dir in $subdirs) {
    $size = (Get-ChildItem -Path $dir.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($size) {
        Write-Host ("    {0,-20} {1}" -f $dir.Name, (Format-Size $size))
    }
}
$totalSize = (Get-ChildItem -Path $Out -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
Write-Host ""
Write-Host ("  Total: {0}" -f (Format-Size $totalSize)) -ForegroundColor White

if ($script:FailedFiles -gt 0) {
    Write-Host ""
    Write-Host "  WARNING: $($script:FailedFiles) files failed. Re-run this script to retry." -ForegroundColor Red
    exit 1
}
