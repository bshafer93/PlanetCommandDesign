#!/bin/bash
# ============================================================================
# NASA JPL DE441 Ephemeris - Complete Data Downloader
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
#   chmod +x download_de441.sh
#   ./download_de441.sh
#
# To download only specific categories, edit the DOWNLOAD_* flags below.
# ============================================================================

set -euo pipefail

# ---- Configuration: toggle categories on/off ----
DOWNLOAD_BSP=true          # DE441 binary SPK file (~3.1 GB)
DOWNLOAD_ASCII=true        # DE441 ASCII coefficients (~8.8 GB)
DOWNLOAD_LINUX=true        # DE441 Linux binary (~2.6 GB)
DOWNLOAD_NIO=true          # DE441 NIO format (~3.3 GB)
DOWNLOAD_SMALL_BODIES=false # Asteroid perturbers for DE441 (~15.7 GB)
DOWNLOAD_SATELLITES=false   # All satellite ephemerides (~50 GB)
DOWNLOAD_BPC=true          # Lunar orientation frames (~13 MB)
DOWNLOAD_DOCS=true         # IOMs, papers, Fortran readers (~30 MB)
DOWNLOAD_TEST_DATA=true    # Verification test data (~10 MB)

# ---- Base URLs ----
BASE="https://ssd.jpl.nasa.gov/ftp/eph"
PLANETS="$BASE/planets"

# ---- Output directory (script's location) ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR"

# ---- Counters ----
TOTAL_FILES=0
SKIPPED_FILES=0
DOWNLOADED_FILES=0
FAILED_FILES=0

# ---- Download helper ----
# Uses curl with resume support. Skips files that already match remote size.
download() {
    local url="$1"
    local dest="$2"

    TOTAL_FILES=$((TOTAL_FILES + 1))

    # Create parent directory
    mkdir -p "$(dirname "$dest")"

    if [[ -f "$dest" ]]; then
        # Check if file is complete by attempting resume; curl exits 0 if nothing to do
        local http_code
        http_code=$(curl -s -o /dev/null -w '%{http_code}' -L -C - --connect-timeout 30 "$url" 2>/dev/null || echo "000")
        if [[ "$http_code" == "416" ]]; then
            # 416 = Range Not Satisfiable = file already complete
            echo "  [SKIP] $(basename "$dest") (already complete)"
            SKIPPED_FILES=$((SKIPPED_FILES + 1))
            return 0
        fi
    fi

    echo "  [GET]  $(basename "$dest")"
    if curl -L -C - --connect-timeout 30 --retry 5 --retry-delay 10 \
         --progress-bar -o "$dest" "$url"; then
        DOWNLOADED_FILES=$((DOWNLOADED_FILES + 1))
    else
        echo "  [FAIL] $(basename "$dest") - curl exit code $?"
        FAILED_FILES=$((FAILED_FILES + 1))
    fi
}

echo "============================================================"
echo "  NASA JPL DE441 Ephemeris Downloader"
echo "  Output: $OUT"
echo "============================================================"
echo ""

# ============================================================================
# 1. DE441 Binary SPK (SPICE kernel) — ~3.1 GB
# ============================================================================
if $DOWNLOAD_BSP; then
    echo ">>> [1/9] DE441 Binary SPK (~3.1 GB)"
    mkdir -p "$OUT/bsp"
    download "$PLANETS/bsp/de441.bsp"    "$OUT/bsp/de441.bsp"
    download "$PLANETS/bsp/de440.bsp"    "$OUT/bsp/de440.bsp"
    download "$PLANETS/bsp/de440s.bsp"   "$OUT/bsp/de440s.bsp"
    download "$PLANETS/bsp/README.txt"   "$OUT/bsp/README.txt"
    echo ""
fi

# ============================================================================
# 2. DE441 ASCII Chebyshev Coefficients — ~8.8 GB (31 files)
# ============================================================================
if $DOWNLOAD_ASCII; then
    echo ">>> [2/9] DE441 ASCII coefficients (~8.8 GB)"
    mkdir -p "$OUT/ascii"
    download "$PLANETS/ascii/de441/header.441"  "$OUT/ascii/header.441"
    download "$PLANETS/ascii/de441/testpo.441"  "$OUT/ascii/testpo.441"

    # Negative millennia: ascm01000 through ascm13000
    for i in $(seq -w 1000 1000 13000); do
        download "$PLANETS/ascii/de441/ascm${i}.441" "$OUT/ascii/ascm${i}.441"
    done

    # Positive millennia: ascp00000 through ascp16000
    for i in $(seq -w 0 1000 16000); do
        padded=$(printf "%05d" "$i")
        download "$PLANETS/ascii/de441/ascp${padded}.441" "$OUT/ascii/ascp${padded}.441"
    done
    echo ""
fi

# ============================================================================
# 3. DE441 Linux Binary — ~2.6 GB
# ============================================================================
if $DOWNLOAD_LINUX; then
    echo ">>> [3/9] DE441 Linux binary (~2.6 GB)"
    mkdir -p "$OUT/linux"
    download "$PLANETS/Linux/de441/linux_m13000p17000.441" "$OUT/linux/linux_m13000p17000.441"
    download "$PLANETS/Linux/de441/header.441"              "$OUT/linux/header.441"
    download "$PLANETS/Linux/de441/testpo.441"              "$OUT/linux/testpo.441"
    echo ""
fi

# ============================================================================
# 4. DE441 NIO Format — ~3.3 GB
# ============================================================================
if $DOWNLOAD_NIO; then
    echo ">>> [4/9] DE441 NIO format (~3.3 GB)"
    mkdir -p "$OUT/nio"
    download "$PLANETS/nio/de441.ftp"   "$OUT/nio/de441.ftp"
    download "$PLANETS/nio/README.txt"  "$OUT/nio/README.txt"
    echo ""
fi

# ============================================================================
# 5. Small Bodies (Asteroid Perturbers for DE441) — ~15.7 GB
# ============================================================================
if $DOWNLOAD_SMALL_BODIES; then
    echo ">>> [5/9] Small body ephemerides (~15.7 GB)"
    mkdir -p "$OUT/small_bodies"
    download "$BASE/small_bodies/asteroids_de441/sb441-n16.bsp"                         "$OUT/small_bodies/sb441-n16.bsp"
    download "$BASE/small_bodies/asteroids_de441/sb441-n373.bsp"                        "$OUT/small_bodies/sb441-n373.bsp"
    download "$BASE/small_bodies/asteroids_de441/sb441-n373s.bsp"                       "$OUT/small_bodies/sb441-n373s.bsp"
    download "$BASE/small_bodies/asteroids_de441/SB441_IOM392R-21-005_perturbers.pdf"   "$OUT/small_bodies/SB441_IOM392R-21-005_perturbers.pdf"
    echo ""
fi

# ============================================================================
# 6. Satellite Ephemerides (all planets) — ~50 GB
# ============================================================================
if $DOWNLOAD_SATELLITES; then
    echo ">>> [6/9] Satellite ephemerides (~50 GB)"
    mkdir -p "$OUT/satellites"

    SAT_BSP="$BASE/satellites/bsp"

    # -- Jupiter system --
    echo "    Jupiter moons..."
    for f in jup340.bsp jup341.bsp jup343.bsp jup344.bsp jup345.bsp jup346.bsp \
             jup347.bsp jup357.bsp jup357_1600.bsp jup363.bsp jup365.bsp \
             jup380s.bsp jup387.2021_2400.bsp jup387xl.bsp; do
        download "$SAT_BSP/$f" "$OUT/satellites/$f"
    done

    # -- Mars system --
    echo "    Mars moons..."
    for f in mar097.bsp mar097.2100-2500.bsp mar099.bsp; do
        download "$SAT_BSP/$f" "$OUT/satellites/$f"
    done

    # -- Saturn system --
    echo "    Saturn moons..."
    for f in sat360xl.bsp sat427l.bsp sat428.bsp sat440l.bsp sat441l.bsp \
             sat441xl.back.bsp sat441xl.fwrd.bsp sat450.bsp sat452.bsp \
             sat453.bsp sat454.bsp sat455.bsp sat456.bsp sat457.bsp \
             sat143.bsp daphnis.sat393.bsp; do
        download "$SAT_BSP/$f" "$OUT/satellites/$f"
    done

    # -- Neptune system --
    echo "    Neptune moons..."
    for f in nep090.bsp nep096.bsp nep097.bsp nep100.bsp nep101.bsp \
             nep101.30kyr.bsp nep102.bsp nep103.bsp nep104.bsp nep105.bsp \
             Triton.nep097.30kyr.bsp; do
        download "$SAT_BSP/$f" "$OUT/satellites/$f"
    done

    # -- Uranus system --
    echo "    Uranus moons..."
    for f in ura111.bsp ura111.30kyr.bsp ura111.xl.bsp ura115.bsp \
             ura116.bsp ura116.30kyr.bsp ura117.bsp ura155.bsp ura158.bsp \
             ura159.bsp ura160.bsp ura161.bsp ura167.bsp ura178.bsp \
             ura182.bsp ura183.bsp ura184.bsp; do
        download "$SAT_BSP/$f" "$OUT/satellites/$f"
    done

    # -- Pluto system --
    echo "    Pluto moons..."
    for f in plu022.bsp plu043.bsp plu049.bsp plu055.bsp plu058.bsp plu060.bsp; do
        download "$SAT_BSP/$f" "$OUT/satellites/$f"
    done

    # -- TNO satellites --
    echo "    TNO satellites..."
    for f in tnosat_v001_20000617_jpl082_20230601.bsp \
             tnosat_v001_20050000_jpl043_20220908.bsp \
             tnosat_v001_20090482_jpl043_20220908.bsp \
             tnosat_v001_20120347_jpl025_20220908.bsp \
             tnosat_v001_20136108_jpl110_20220908.bsp \
             tnosat_v001_20136199_jpl080_20220908.bsp \
             tnosat_v001_20469705_jpl009_20220908.bsp \
             tnosat_v001_20612095_jpl006_20220908.bsp \
             tnosat_v001_20612687_jpl008_20220908.bsp \
             tnosat_v001_53031823_jpl010_20220908.bsp \
             tnosat_v001_53092511_jpl005_20220908.bsp \
             tnosat_v001b_20136108_jpl110_20221014.bsp; do
        download "$SAT_BSP/$f" "$OUT/satellites/$f"
    done

    # -- Approach ephemerides --
    echo "    Approach ephemerides..."
    for f in 130412AP_RE_90165_18018.bsp 130528BP_IRRE_00256_25017.bsp \
             140127AP_RE_90165_18018.bsp 140809BP_IRRE_00256_25017.bsp \
             150422AP_RE_90165_18018.bsp 150720AP_RE_90165_18018.bsp \
             161011AP_RE_90165_18018.bsp 161101AP_RE_90165_18018.bsp \
             180927AP_RE_90165_18018.bsp 20000617.bsp \
             se_jup342.bsp se_pluto058.xl.bsp; do
        download "$SAT_BSP/$f" "$OUT/satellites/$f"
    done

    # -- Log files --
    for f in jup345.spk.log jup346.spk.log jup347.log jup380s.log jup365.spk.txt \
             mar099.spk.log sat441l.log sat450.spk.txt sat452.log sat453.log \
             sat454.log sat455.log sat456.log sat457.log ura117.spk.log \
             ura182.log ura183.log ura184.log plu060.spk.log plu060.spk.tex \
             nep102.spk.log nep103.spk.log nep104.spk.log nep105.log; do
        download "$SAT_BSP/$f" "$OUT/satellites/$f"
    done
    echo ""
fi

# ============================================================================
# 7. Lunar Frame Kernels (BPC) — ~13 MB
# ============================================================================
if $DOWNLOAD_BPC; then
    echo ">>> [7/9] Lunar orientation frames (~13 MB)"
    mkdir -p "$OUT/bpc"
    download "$PLANETS/bpc/README.txt"                           "$OUT/bpc/README.txt"
    download "$PLANETS/bpc/moon_190627.tf"                       "$OUT/bpc/moon_190627.tf"
    download "$PLANETS/bpc/moon_pa_de430_1550-2650.bpc"          "$OUT/bpc/moon_pa_de430_1550-2650.bpc"
    echo ""
fi

# ============================================================================
# 8. Documentation (IOMs, papers, Fortran source) — ~30 MB
# ============================================================================
if $DOWNLOAD_DOCS; then
    echo ">>> [8/9] Documentation & tools (~30 MB)"
    mkdir -p "$OUT/docs"
    mkdir -p "$OUT/fortran"

    # IOMs and papers
    for f in ExplSupplChap8.pdf LLR_Model_2020_DR.pdf de403.iom.pdf de405.iom.pdf \
             de405_for_Mars_Surveyor_01nov2000.pdf de409.iom.pdf de410.iom.pdf \
             de414.iom.pdf de418.iom.v3.pdf de421.iom.v1.pdf de421_moon_coord_iom.pdf \
             de423.iom.pdf de424.iom.pdf de430_moon_coord_iom.pdf de432.pluto.05may2014.pdf \
             de434.iom.pdf de435.iom.pdf de440.aj.pdf; do
        download "$PLANETS/ioms/$f" "$OUT/docs/$f"
    done

    # DE440/441 overview paper
    download "https://ssd.jpl.nasa.gov/doc/Park.2021.AJ.DE440.pdf" "$OUT/docs/Park.2021.AJ.DE440.pdf"

    # Top-level READMEs
    download "$PLANETS/README.txt"          "$OUT/docs/planets_README.txt"
    download "$PLANETS/CDROM.notes"         "$OUT/docs/CDROM.notes"
    download "$PLANETS/other_readers.txt"   "$OUT/docs/other_readers.txt"

    # Fortran source for reading ephemerides
    for f in README.txt asc2eph.f testeph.f testeph1.f userguide.txt; do
        download "$PLANETS/fortran/$f" "$OUT/fortran/$f"
    done
    echo ""
fi

# ============================================================================
# 9. Test / Verification Data — ~10 MB
# ============================================================================
if $DOWNLOAD_TEST_DATA; then
    echo ">>> [9/9] Test & verification data (~10 MB)"
    mkdir -p "$OUT/test_data"
    for f in testpo.102.gz testpo.200 testpo.202 testpo.403 testpo.405 testpo.406 \
             testpo.410 testpo.413 testpo.414 testpo.418 testpo.421 testpo.421x \
             testpo.422 testpo.423; do
        download "$PLANETS/test-data/$f" "$OUT/test_data/$f"
    done
    echo ""
fi

# ============================================================================
# Summary
# ============================================================================
echo "============================================================"
echo "  Download Complete"
echo "============================================================"
echo "  Total files:      $TOTAL_FILES"
echo "  Downloaded:       $DOWNLOADED_FILES"
echo "  Skipped (exist):  $SKIPPED_FILES"
echo "  Failed:           $FAILED_FILES"
echo ""
echo "  Location: $OUT"
echo ""

# Show disk usage
if command -v du &>/dev/null; then
    echo "  Disk usage:"
    du -sh "$OUT"/*/ 2>/dev/null | sed 's/^/    /'
    echo ""
    echo "  Total:"
    du -sh "$OUT" | sed 's/^/    /'
fi

if [[ $FAILED_FILES -gt 0 ]]; then
    echo ""
    echo "  WARNING: $FAILED_FILES files failed. Re-run this script to retry."
    exit 1
fi
