<script lang="ts">
  import { Chart, registerables } from 'chart.js';
  import SliderInput from '../../components/SliderInput.svelte';
  Chart.register(...registerables);

  type SubTab = 'projectile' | 'laser' | 'particle';
  let activeSubTab: SubTab = $state('projectile');

  // ── Shape types ────────────────────────────────────
  type Shape = 'box' | 'sphere' | 'rod';
  let shape: Shape = $state('box');

  // Dimensions in meters
  let dimX = $state(0.1);
  let dimY = $state(0.1);
  let dimZ = $state(0.1);

  // ── Materials with density (kg/m³) ─────────────────
  const materials: { name: string; density: number }[] = [
    { name: 'Steel', density: 7850 },
    { name: 'Lead', density: 11340 },
    { name: 'Tungsten', density: 19250 },
    { name: 'Uranium', density: 19100 },
    { name: 'Copper', density: 8960 },
    { name: 'Nickel', density: 8908 },
  ];
  let materialIndex = $state(0);

  // ── Speed ──────────────────────────────────────────
  let speed = $state(1000);
  let speedUnit: 'm/s' | 'km/s' = $state('m/s');

  // ── Computed values ────────────────────────────────
  let volume = $derived.by(() => {
    switch (shape) {
      case 'box':
        return dimX * dimY * dimZ;
      case 'sphere':
        // dimX = radius
        return (4 / 3) * Math.PI * Math.pow(dimX, 3);
      case 'rod':
        // dimX = radius, dimY = length
        return Math.PI * Math.pow(dimX, 2) * dimY;
    }
  });

  let density = $derived(materials[materialIndex].density);
  let mass = $derived(volume * density);

  let speedMs = $derived((speedUnit as string) === 'km/s' ? speed * 1000 : speed);
  let energy = $derived(0.5 * mass * speedMs * speedMs);

  // ── Format energy with auto-scaling ────────────────
  function formatEnergy(j: number): string {
    if (!isFinite(j) || isNaN(j)) return '—';
    if (j >= 1e9) return (j / 1e9).toLocaleString(undefined, { maximumFractionDigits: 3 }) + ' GJ';
    if (j >= 1e6) return (j / 1e6).toLocaleString(undefined, { maximumFractionDigits: 3 }) + ' MJ';
    if (j >= 1e3) return (j / 1e3).toLocaleString(undefined, { maximumFractionDigits: 3 }) + ' kJ';
    return j.toLocaleString(undefined, { maximumFractionDigits: 3 }) + ' J';
  }

  function formatMass(kg: number): string {
    if (!isFinite(kg) || isNaN(kg)) return '—';
    if (kg >= 1000) return (kg / 1000).toLocaleString(undefined, { maximumFractionDigits: 3 }) + ' t';
    if (kg < 0.01) return (kg * 1000).toLocaleString(undefined, { maximumFractionDigits: 3 }) + ' g';
    return kg.toLocaleString(undefined, { maximumFractionDigits: 4 }) + ' kg';
  }

  function formatVolume(m3: number): string {
    if (!isFinite(m3) || isNaN(m3)) return '—';
    if (m3 < 0.000001) return (m3 * 1e9).toLocaleString(undefined, { maximumFractionDigits: 3 }) + ' mm³';
    if (m3 < 0.001) return (m3 * 1e6).toLocaleString(undefined, { maximumFractionDigits: 3 }) + ' cm³';
    return m3.toLocaleString(undefined, { maximumFractionDigits: 6 }) + ' m³';
  }

  // ══════════════════════════════════════════════════════
  // ── Laser Calculator ─────────────────────────────────
  // ══════════════════════════════════════════════════════

  // Chart constants
  const LC = {
    text: '#e2e8f0',
    textDim: '#8492a6',
    border: '#2a3142',
    surface: '#1a2030',
    accent: '#63b3ed',
    orange: '#ed8936',
    green: '#68d391',
    red: '#fc8181',
    purple: '#b794f4',
  };
  const chartFont = { family: "'JetBrains Mono', monospace" as const, size: 12, weight: 500 as const };

  let laserAperture = $state(30);     // cm
  let laserWavelength = $state(1064); // nm
  let laserPower = $state(1);         // MW  (stored in MW; 100 GW = 100000)
  let laserRange = $state(100);       // km

  function formatPowerCompact(mw: number): string {
    if (mw >= 1000) return (mw / 1000).toPrecision(3) + ' GW';
    return (+mw.toPrecision(3)) + ' MW';
  }

  // ── Absorption model for steel vs wavelength ─────────
  function getAbsorption(nm: number): number {
    const pts: [number, number][] = [
      [200, 0.58], [400, 0.50], [700, 0.42],
      [1064, 0.38], [2000, 0.32], [5000, 0.25], [10600, 0.10],
    ];
    if (nm <= pts[0][0]) return pts[0][1];
    if (nm >= pts[pts.length - 1][0]) return pts[pts.length - 1][1];
    for (let i = 0; i < pts.length - 1; i++) {
      if (nm >= pts[i][0] && nm <= pts[i + 1][0]) {
        const t = (nm - pts[i][0]) / (pts[i + 1][0] - pts[i][0]);
        return pts[i][1] + t * (pts[i + 1][1] - pts[i][1]);
      }
    }
    return 0.35;
  }

  let laserAbsorption = $derived(getAbsorption(laserWavelength));

  // Spot diameter via diffraction limit: d = 2.44 × λ × R / D
  let spotDiameter = $derived(2.44 * (laserWavelength * 1e-9) * (laserRange * 1000) / (laserAperture / 100));
  let spotArea = $derived(Math.PI * (spotDiameter / 2) ** 2);

  // Power density at target
  let absorbedPowerDensity = $derived(laserAbsorption * (laserPower * 1e6) / spotArea); // W/m²

  // Steel thermal properties
  const STEEL = {
    density: 7850,           // kg/m³
    specificHeat: 500,       // J/(kg·K)
    meltingTemp: 1773,       // K
    ambientTemp: 300,        // K
    latentHeatFusion: 270000, // J/kg
  };
  const steelEnergyPerVolume = STEEL.density * (
    STEEL.specificHeat * (STEEL.meltingTemp - STEEL.ambientTemp) + STEEL.latentHeatFusion
  ); // J/m³

  // Penetration depth (m) = absorbed_power_density × time / energy_per_volume
  function calcPen(apd: number, t: number): number {
    return apd * t / steelEnergyPerVolume;
  }

  const maxPlate = 0.3; // meters
  const durations = [1, 5, 10, 30];
  const durColors = [LC.accent, LC.green, LC.orange, LC.red];
  const durLabels = ['1 s', '5 s', '10 s', '30 s'];

  let penDepths = $derived(durations.map(t => calcPen(absorbedPowerDensity, t)));
  let penPcts = $derived(penDepths.map(d => Math.min(d / maxPlate * 100, 100)));

  function formatDepth(m: number): string {
    if (!isFinite(m) || isNaN(m)) return '—';
    if (m >= 1) return m.toFixed(2) + ' m';
    if (m >= 0.01) return (m * 100).toFixed(1) + ' cm';
    if (m >= 0.001) return (m * 1000).toFixed(2) + ' mm';
    return (m * 1e6).toFixed(0) + ' μm';
  }

  function formatSpot(m: number): string {
    if (!isFinite(m) || isNaN(m)) return '—';
    if (m >= 1) return m.toFixed(2) + ' m';
    if (m >= 0.01) return (m * 100).toFixed(1) + ' cm';
    return (m * 1000).toFixed(2) + ' mm';
  }

  function formatPowerDensity(wm2: number): string {
    if (!isFinite(wm2) || isNaN(wm2)) return '—';
    if (wm2 >= 1e9) return (wm2 / 1e9).toFixed(2) + ' GW/m²';
    if (wm2 >= 1e6) return (wm2 / 1e6).toFixed(2) + ' MW/m²';
    if (wm2 >= 1e3) return (wm2 / 1e3).toFixed(1) + ' kW/m²';
    return wm2.toFixed(0) + ' W/m²';
  }

  // ── Color gradient for heatmap ─────────────────────
  // red → green → blue → purple mapped on log depth scale
  function lerp3(a: [number,number,number], b: [number,number,number], t: number): [number,number,number] {
    return [
      Math.round(a[0] + (b[0] - a[0]) * t),
      Math.round(a[1] + (b[1] - a[1]) * t),
      Math.round(a[2] + (b[2] - a[2]) * t),
    ];
  }

  function penToColor(depth_m: number): [number,number,number] {
    const mm = depth_m * 1000;
    const red:    [number,number,number] = [252, 129, 129];
    const green:  [number,number,number] = [104, 211, 145];
    const blue:   [number,number,number] = [ 99, 179, 237];
    const purple: [number,number,number] = [183, 148, 244];

    if (mm < 0.01) return red; // negligible

    // Log-scale mapping: 0.01mm → 0, 300mm → 1
    const logMin = -2, logMax = Math.log10(300);
    const t = Math.max(0, Math.min(1, (Math.log10(mm) - logMin) / (logMax - logMin)));

    const tGreen = (0 - logMin) / (logMax - logMin);                    // ~0.45 (1mm)
    const tBlue  = (Math.log10(50) - logMin) / (logMax - logMin);       // ~0.83 (50mm)

    if (t <= tGreen) return lerp3(red, green, t / tGreen);
    if (t <= tBlue)  return lerp3(green, blue, (t - tGreen) / (tBlue - tGreen));
    return lerp3(blue, purple, (t - tBlue) / (1 - tBlue));
  }

  // Penetration for arbitrary power/range (independent of slider state)
  function calcPenStandalone(powerMW: number, rangeKm: number, apertCm: number, wavNm: number): number {
    const abs = getAbsorption(wavNm);
    const spotD = 2.44 * (wavNm * 1e-9) * (rangeKm * 1000) / (apertCm / 100);
    const spotA = Math.PI * (spotD / 2) ** 2;
    const apd = abs * (powerMW * 1e6) / spotA;
    return apd / steelEnergyPerVolume; // 1-second impulse
  }

  // ── Charts ─────────────────────────────────────────
  let laserCanvas = $state<HTMLCanvasElement>();
  let heatmapCanvas = $state<HTMLCanvasElement>();

  $effect(() => {
    if (!laserCanvas || activeSubTab !== 'laser') return;
    const apd = absorbedPowerDensity;
    const numPoints = 200;
    const maxTime = 30;
    const times: number[] = [];
    const depths: number[] = [];
    for (let i = 0; i <= numPoints; i++) {
      const t = (i / numPoints) * maxTime;
      times.push(t);
      depths.push(Math.min(calcPen(apd, t), maxPlate));
    }
    const chart = new Chart(laserCanvas, {
      type: 'line',
      data: {
        labels: times.map(t => t.toFixed(1)),
        datasets: [
          {
            label: 'Penetration Depth',
            data: depths.map(d => d * 1000), // convert to mm
            borderColor: LC.accent,
            backgroundColor: LC.accent + '22',
            fill: true,
            tension: 0.3,
            pointRadius: 0,
          },
          {
            label: 'Plate Thickness (300mm)',
            data: times.map(() => maxPlate * 1000),
            borderColor: LC.red + '88',
            borderDash: [6, 4],
            pointRadius: 0,
            fill: false,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 2.2,
        scales: {
          x: {
            title: { display: true, text: 'Time (s)', color: LC.textDim, font: chartFont },
            ticks: {
              color: LC.textDim,
              font: { size: 10 },
              maxTicksLimit: 12,
              callback: (_, i) => {
                const t = times[i as number];
                return t !== undefined && t % 5 === 0 ? t + 's' : '';
              },
            },
            grid: { color: LC.border },
          },
          y: {
            title: { display: true, text: 'Depth (mm)', color: LC.textDim, font: chartFont },
            ticks: { color: LC.textDim, font: { size: 10 } },
            grid: { color: LC.border },
            min: 0,
            max: Math.max(maxPlate * 1000, depths[depths.length - 1] * 1000 * 1.1),
          },
        },
        plugins: {
          title: {
            display: true,
            text: 'Steel Penetration vs Exposure Time',
            color: LC.text,
            font: { ...chartFont, size: 13, weight: 600 as const },
          },
          legend: {
            labels: { color: LC.textDim, font: { size: 10 }, padding: 8 },
          },
          tooltip: {
            backgroundColor: LC.surface,
            borderColor: LC.border,
            borderWidth: 1,
            titleColor: LC.text,
            bodyColor: LC.textDim,
            callbacks: {
              title: (items) => items[0].label + ' s',
              label: (item) => ' ' + item.dataset.label + ': ' + Number(item.raw).toFixed(2) + ' mm',
            },
          },
        },
      },
    });
    return () => chart.destroy();
  });

  // ── Range vs Power Heatmap ───────────────────────────
  $effect(() => {
    if (!heatmapCanvas || activeSubTab !== 'laser') return;
    const ctx = heatmapCanvas.getContext('2d')!;

    const W = 620, H = 420;
    heatmapCanvas.width = W;
    heatmapCanvas.height = H;

    const M = { top: 32, right: 85, bottom: 48, left: 68 };
    const pX = M.left, pY = M.top;
    const pW = W - M.left - M.right;
    const pH = H - M.top - M.bottom;

    const apert = laserAperture;
    const wav = laserWavelength;
    const curRange = laserRange;
    const curPower = laserPower;

    const logRMin = 0, logRMax = 3;   // log10(1 km) → log10(1000 km)
    const logPMin = -1, logPMax = 5;  // log10(0.1 MW) → log10(100 GW)

    // Background
    ctx.fillStyle = LC.surface;
    ctx.fillRect(0, 0, W, H);

    // Compute heatmap at low res, scale up
    const gridW = 150, gridH = 100;
    const tmp = document.createElement('canvas');
    tmp.width = gridW;
    tmp.height = gridH;
    const tmpCtx = tmp.getContext('2d')!;
    const imgData = tmpCtx.createImageData(gridW, gridH);
    const px = imgData.data;

    for (let row = 0; row < gridH; row++) {
      const tY = row / (gridH - 1);
      const pMW = Math.pow(10, logPMax - tY * (logPMax - logPMin));
      for (let col = 0; col < gridW; col++) {
        const tX = col / (gridW - 1);
        const rKm = Math.pow(10, logRMin + tX * (logRMax - logRMin));
        const pen = calcPenStandalone(pMW, rKm, apert, wav);
        const [r, g, b] = penToColor(pen);
        const idx = (row * gridW + col) * 4;
        px[idx] = r; px[idx+1] = g; px[idx+2] = b; px[idx+3] = 255;
      }
    }
    tmpCtx.putImageData(imgData, 0, 0);
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(tmp, pX, pY, pW, pH);

    // ── Crosshairs ────────────────────────────────────
    const xCH = pX + ((Math.log10(Math.max(curRange, 1)) - logRMin) / (logRMax - logRMin)) * pW;
    const yCH = pY + (1 - (Math.log10(Math.max(curPower, 0.1)) - logPMin) / (logPMax - logPMin)) * pH;

    ctx.strokeStyle = '#ffffffaa';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 3]);
    ctx.beginPath();
    ctx.moveTo(xCH, pY); ctx.lineTo(xCH, pY + pH);
    ctx.moveTo(pX, yCH); ctx.lineTo(pX + pW, yCH);
    ctx.stroke();
    ctx.setLineDash([]);

    // Dot
    ctx.beginPath();
    ctx.arc(xCH, yCH, 5, 0, Math.PI * 2);
    ctx.fillStyle = '#ffffff';
    ctx.fill();
    ctx.strokeStyle = '#000';
    ctx.lineWidth = 1.5;
    ctx.stroke();

    // Label at crosshair
    const curPen = calcPenStandalone(curPower, curRange, apert, wav);
    const penLabel = formatDepth(curPen);
    ctx.font = 'bold 11px JetBrains Mono, monospace';
    const onRight = xCH < pX + pW / 2;
    ctx.textAlign = onRight ? 'left' : 'right';
    ctx.textBaseline = 'bottom';
    const lx = xCH + (onRight ? 10 : -10);
    const tm = ctx.measureText(penLabel);
    const boxX = onRight ? lx - 3 : lx - tm.width - 3;
    ctx.fillStyle = '#000000cc';
    ctx.fillRect(boxX, yCH - 24, tm.width + 6, 17);
    ctx.fillStyle = '#ffffff';
    ctx.fillText(penLabel, lx, yCH - 9);

    // ── Axes ──────────────────────────────────────────
    ctx.strokeStyle = LC.border;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(pX, pY); ctx.lineTo(pX, pY + pH); ctx.lineTo(pX + pW, pY + pH);
    ctx.stroke();

    // X ticks (Range)
    ctx.fillStyle = LC.textDim;
    ctx.font = '10px JetBrains Mono, monospace';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    for (const r of [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000]) {
      const x = pX + ((Math.log10(r) - logRMin) / (logRMax - logRMin)) * pW;
      ctx.fillStyle = LC.textDim;
      ctx.fillText(String(r), x, pY + pH + 5);
      ctx.beginPath(); ctx.moveTo(x, pY + pH); ctx.lineTo(x, pY + pH + 3);
      ctx.strokeStyle = LC.textDim; ctx.stroke();
    }
    ctx.font = '11px JetBrains Mono, monospace';
    ctx.fillText('Range (km)', pX + pW / 2, pY + pH + 22);

    // Y ticks (Power)
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    ctx.font = '9px JetBrains Mono, monospace';
    const pTicks: [number, string][] = [
      [0.1,'0.1 MW'],[1,'1 MW'],[10,'10 MW'],[100,'100 MW'],
      [1000,'1 GW'],[10000,'10 GW'],[100000,'100 GW'],
    ];
    for (const [pv, label] of pTicks) {
      const y = pY + (1 - (Math.log10(pv) - logPMin) / (logPMax - logPMin)) * pH;
      ctx.fillStyle = LC.textDim;
      ctx.fillText(label, pX - 5, y);
      ctx.beginPath(); ctx.moveTo(pX - 3, y); ctx.lineTo(pX, y);
      ctx.strokeStyle = LC.textDim; ctx.stroke();
    }

    // Title
    ctx.fillStyle = LC.text;
    ctx.font = 'bold 12px JetBrains Mono, monospace';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';
    ctx.fillText(`Range vs Power \u2014 1s Impulse (${apert}cm aperture, ${wav}nm)`, W / 2, pY - 8);

    // ── Color legend bar (right side) ─────────────────
    const legX = pX + pW + 14, legW = 12;
    const logDMin = -2, logDMax = Math.log10(300);

    for (let i = 0; i < pH; i++) {
      const t = i / pH; // 0 = top (max depth), 1 = bottom (min depth)
      const mm = Math.pow(10, logDMax - t * (logDMax - logDMin));
      const [r, g, b] = penToColor(mm / 1000);
      ctx.fillStyle = `rgb(${r},${g},${b})`;
      ctx.fillRect(legX, pY + i, legW, 1.5);
    }
    ctx.strokeStyle = LC.border;
    ctx.strokeRect(legX, pY, legW, pH);

    // Legend labels
    ctx.fillStyle = LC.textDim;
    ctx.font = '9px JetBrains Mono, monospace';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    for (const { mm, text } of [
      { mm: 300, text: '30cm' }, { mm: 50, text: '5cm' },
      { mm: 1, text: '1mm' }, { mm: 0.01, text: '~0' },
    ]) {
      const y = mm <= 0.01
        ? pY + pH
        : pY + ((logDMax - Math.log10(mm)) / (logDMax - logDMin)) * pH;
      ctx.fillText(text, legX + legW + 3, y);
    }

    return () => {};
  });

  // ══════════════════════════════════════════════════════
  // ── Particle Beam Calculator ──────────────────────────
  // ══════════════════════════════════════════════════════

  let beamType = $state<'neutral' | 'charged'>('neutral');
  let pbDivergence = $state(10);       // μrad (half-angle)
  let pbEnergy = $state(100);          // MeV (particle kinetic energy)
  let pbPower = $state(1);             // MW
  let pbRange = $state(1);             // km

  const PB_DEPOSITION = 0.60;          // 60% deposition efficiency
  const PB_R0 = 0.002;                 // 2 mm initial beam radius
  const PROTON_REST_MASS_MEV = 938.272;
  const ALFVEN_CURRENT_PROTON = 3.13e7; // ~31.3 MA

  let pbGamma = $derived(1 + pbEnergy / PROTON_REST_MASS_MEV);
  let pbBeta = $derived(Math.sqrt(1 - 1 / (pbGamma * pbGamma)));
  let pbBetaGamma = $derived(pbBeta * pbGamma);
  let pbCurrent = $derived((pbPower * 1e6) / (pbEnergy * 1e6)); // Amperes

  let pbPerveance = $derived(
    beamType === 'charged'
      ? (2 * pbCurrent) / (ALFVEN_CURRENT_PROTON * Math.pow(pbBetaGamma, 3))
      : 0
  );

  function pbSpotRadiusAt(z_m: number, theta_rad: number, K: number): number {
    if (K === 0) return PB_R0 + theta_rad * z_m;
    return PB_R0 + theta_rad * z_m + (K / (2 * PB_R0)) * z_m * z_m;
  }

  let pbRangeM = $derived(pbRange * 1000);
  let pbTheta = $derived(pbDivergence * 1e-6);
  let pbSpotRadius = $derived(pbSpotRadiusAt(pbRangeM, pbTheta, pbPerveance));
  let pbSpotDiameter = $derived(2 * pbSpotRadius);
  let pbSpotArea = $derived(Math.PI * pbSpotRadius * pbSpotRadius);
  let pbAbsorbedPowerDensity = $derived(PB_DEPOSITION * (pbPower * 1e6) / pbSpotArea);

  let pbPenDepths = $derived(durations.map(t => calcPen(pbAbsorbedPowerDensity, t)));
  let pbPenPcts = $derived(pbPenDepths.map(d => Math.min(d / maxPlate * 100, 100)));

  function calcPenPBStandalone(powerMW: number, rangeKm: number, divUrad: number, energyMeV: number, type: 'neutral' | 'charged'): number {
    const z = rangeKm * 1000;
    const theta = divUrad * 1e-6;
    let K = 0;
    if (type === 'charged') {
      const gamma = 1 + energyMeV / PROTON_REST_MASS_MEV;
      const beta = Math.sqrt(1 - 1 / (gamma * gamma));
      const bg = beta * gamma;
      const current = (powerMW * 1e6) / (energyMeV * 1e6);
      K = (2 * current) / (ALFVEN_CURRENT_PROTON * Math.pow(bg, 3));
    }
    const spotR = pbSpotRadiusAt(z, theta, K);
    const area = Math.PI * spotR * spotR;
    const apd = PB_DEPOSITION * (powerMW * 1e6) / area;
    return apd / steelEnergyPerVolume;
  }

  function formatCurrent(a: number): string {
    if (!isFinite(a) || isNaN(a)) return '—';
    if (a >= 1) return a.toFixed(2) + ' A';
    if (a >= 0.001) return (a * 1000).toFixed(1) + ' mA';
    return (a * 1e6).toFixed(0) + ' μA';
  }

  function formatDivergence(urad: number): string {
    if (urad >= 1000) return (urad / 1000).toFixed(1) + ' mrad';
    return urad.toFixed(1) + ' μrad';
  }

  function formatParticleEnergy(mev: number): string {
    if (mev >= 1000) return (mev / 1000).toFixed(1) + ' GeV';
    return mev.toFixed(0) + ' MeV';
  }

  function formatRangeLabel(km: number): string {
    if (km < 1) return (km * 1000).toFixed(0) + ' m';
    return km.toFixed(km < 10 ? 1 : 0) + ' km';
  }

  // ── Particle beam charts ──────────────────────────────
  let pbChartCanvas = $state<HTMLCanvasElement>();
  let pbHeatmapCanvas = $state<HTMLCanvasElement>();

  // Time vs depth chart
  $effect(() => {
    if (!pbChartCanvas || activeSubTab !== 'particle') return;
    const apd = pbAbsorbedPowerDensity;
    const bt = beamType;
    const numPoints = 200;
    const maxTime = 30;
    const times: number[] = [];
    const depths: number[] = [];
    for (let i = 0; i <= numPoints; i++) {
      const t = (i / numPoints) * maxTime;
      times.push(t);
      depths.push(Math.min(calcPen(apd, t), maxPlate));
    }
    const chart = new Chart(pbChartCanvas, {
      type: 'line',
      data: {
        labels: times.map(t => t.toFixed(1)),
        datasets: [
          {
            label: 'Penetration Depth',
            data: depths.map(d => d * 1000),
            borderColor: LC.green,
            backgroundColor: LC.green + '22',
            fill: true,
            tension: 0.3,
            pointRadius: 0,
          },
          {
            label: 'Plate Thickness (300mm)',
            data: times.map(() => maxPlate * 1000),
            borderColor: LC.red + '88',
            borderDash: [6, 4],
            pointRadius: 0,
            fill: false,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 2.2,
        scales: {
          x: {
            title: { display: true, text: 'Time (s)', color: LC.textDim, font: chartFont },
            ticks: {
              color: LC.textDim,
              font: { size: 10 },
              maxTicksLimit: 12,
              callback: (_, i) => {
                const t = times[i as number];
                return t !== undefined && t % 5 === 0 ? t + 's' : '';
              },
            },
            grid: { color: LC.border },
          },
          y: {
            title: { display: true, text: 'Depth (mm)', color: LC.textDim, font: chartFont },
            ticks: { color: LC.textDim, font: { size: 10 } },
            grid: { color: LC.border },
            min: 0,
            max: Math.max(maxPlate * 1000, depths[depths.length - 1] * 1000 * 1.1),
          },
        },
        plugins: {
          title: {
            display: true,
            text: `Steel Penetration vs Exposure Time (${bt === 'charged' ? 'Charged' : 'Neutral'} Beam)`,
            color: LC.text,
            font: { ...chartFont, size: 13, weight: 600 as const },
          },
          legend: {
            labels: { color: LC.textDim, font: { size: 10 }, padding: 8 },
          },
          tooltip: {
            backgroundColor: LC.surface,
            borderColor: LC.border,
            borderWidth: 1,
            titleColor: LC.text,
            bodyColor: LC.textDim,
            callbacks: {
              title: (items) => items[0].label + ' s',
              label: (item) => ' ' + item.dataset.label + ': ' + Number(item.raw).toFixed(2) + ' mm',
            },
          },
        },
      },
    });
    return () => chart.destroy();
  });

  // Range vs Power heatmap
  $effect(() => {
    if (!pbHeatmapCanvas || activeSubTab !== 'particle') return;
    const ctx = pbHeatmapCanvas.getContext('2d')!;

    const W = 620, H = 420;
    pbHeatmapCanvas.width = W;
    pbHeatmapCanvas.height = H;

    const M = { top: 32, right: 85, bottom: 48, left: 68 };
    const pX = M.left, pY = M.top;
    const pW = W - M.left - M.right;
    const pH = H - M.top - M.bottom;

    const div = pbDivergence;
    const eng = pbEnergy;
    const bt = beamType;
    const curRange = pbRange;
    const curPower = pbPower;

    // 0.001 km (1 m) → 100 km; 0.01 MW (10 kW) → 100 GW
    const logRMin = -3, logRMax = 2;
    const logPMin = -2, logPMax = 5;

    ctx.fillStyle = LC.surface;
    ctx.fillRect(0, 0, W, H);

    const gridW = 150, gridH = 100;
    const tmp = document.createElement('canvas');
    tmp.width = gridW;
    tmp.height = gridH;
    const tmpCtx = tmp.getContext('2d')!;
    const imgData = tmpCtx.createImageData(gridW, gridH);
    const px = imgData.data;

    for (let row = 0; row < gridH; row++) {
      const tY = row / (gridH - 1);
      const pMW = Math.pow(10, logPMax - tY * (logPMax - logPMin));
      for (let col = 0; col < gridW; col++) {
        const tX = col / (gridW - 1);
        const rKm = Math.pow(10, logRMin + tX * (logRMax - logRMin));
        const pen = calcPenPBStandalone(pMW, rKm, div, eng, bt);
        const [r, g, b] = penToColor(pen);
        const idx = (row * gridW + col) * 4;
        px[idx] = r; px[idx+1] = g; px[idx+2] = b; px[idx+3] = 255;
      }
    }
    tmpCtx.putImageData(imgData, 0, 0);
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(tmp, pX, pY, pW, pH);

    // Crosshairs
    const xCH = pX + ((Math.log10(Math.max(curRange, 0.001)) - logRMin) / (logRMax - logRMin)) * pW;
    const yCH = pY + (1 - (Math.log10(Math.max(curPower, 0.01)) - logPMin) / (logPMax - logPMin)) * pH;

    ctx.strokeStyle = '#ffffffaa';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 3]);
    ctx.beginPath();
    ctx.moveTo(xCH, pY); ctx.lineTo(xCH, pY + pH);
    ctx.moveTo(pX, yCH); ctx.lineTo(pX + pW, yCH);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.beginPath();
    ctx.arc(xCH, yCH, 5, 0, Math.PI * 2);
    ctx.fillStyle = '#ffffff';
    ctx.fill();
    ctx.strokeStyle = '#000';
    ctx.lineWidth = 1.5;
    ctx.stroke();

    const curPen = calcPenPBStandalone(curPower, curRange, div, eng, bt);
    const penLabel = formatDepth(curPen);
    ctx.font = 'bold 11px JetBrains Mono, monospace';
    const onRight = xCH < pX + pW / 2;
    ctx.textAlign = onRight ? 'left' : 'right';
    ctx.textBaseline = 'bottom';
    const lx = xCH + (onRight ? 10 : -10);
    const tm = ctx.measureText(penLabel);
    const boxX = onRight ? lx - 3 : lx - tm.width - 3;
    ctx.fillStyle = '#000000cc';
    ctx.fillRect(boxX, yCH - 24, tm.width + 6, 17);
    ctx.fillStyle = '#ffffff';
    ctx.fillText(penLabel, lx, yCH - 9);

    // Axes
    ctx.strokeStyle = LC.border;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(pX, pY); ctx.lineTo(pX, pY + pH); ctx.lineTo(pX + pW, pY + pH);
    ctx.stroke();

    // X ticks (Range)
    ctx.fillStyle = LC.textDim;
    ctx.font = '10px JetBrains Mono, monospace';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    const rTicks: [number, string][] = [
      [0.001, '1m'], [0.01, '10m'], [0.1, '100m'],
      [1, '1km'], [10, '10km'], [100, '100km'],
    ];
    for (const [r, label] of rTicks) {
      const x = pX + ((Math.log10(r) - logRMin) / (logRMax - logRMin)) * pW;
      ctx.fillStyle = LC.textDim;
      ctx.fillText(label, x, pY + pH + 5);
      ctx.beginPath(); ctx.moveTo(x, pY + pH); ctx.lineTo(x, pY + pH + 3);
      ctx.strokeStyle = LC.textDim; ctx.stroke();
    }
    ctx.font = '11px JetBrains Mono, monospace';
    ctx.fillText('Range', pX + pW / 2, pY + pH + 22);

    // Y ticks (Power)
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    ctx.font = '9px JetBrains Mono, monospace';
    const pTicks: [number, string][] = [
      [0.01, '10 kW'], [0.1, '100 kW'], [1, '1 MW'], [10, '10 MW'],
      [100, '100 MW'], [1000, '1 GW'], [10000, '10 GW'], [100000, '100 GW'],
    ];
    for (const [pv, label] of pTicks) {
      const y = pY + (1 - (Math.log10(pv) - logPMin) / (logPMax - logPMin)) * pH;
      ctx.fillStyle = LC.textDim;
      ctx.fillText(label, pX - 5, y);
      ctx.beginPath(); ctx.moveTo(pX - 3, y); ctx.lineTo(pX, y);
      ctx.strokeStyle = LC.textDim; ctx.stroke();
    }

    // Title
    const beamLabel = bt === 'charged' ? 'Charged' : 'Neutral';
    const titleDetail = bt === 'charged'
      ? `${beamLabel}, ${formatDivergence(div)}, ${formatParticleEnergy(eng)}`
      : `${beamLabel}, ${formatDivergence(div)}`;
    ctx.fillStyle = LC.text;
    ctx.font = 'bold 12px JetBrains Mono, monospace';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';
    ctx.fillText(`Range vs Power \u2014 1s Impulse (${titleDetail})`, W / 2, pY - 8);

    // Color legend bar
    const legX = pX + pW + 14, legW = 12;
    const logDMin = -2, logDMax = Math.log10(300);

    for (let i = 0; i < pH; i++) {
      const t = i / pH;
      const mm = Math.pow(10, logDMax - t * (logDMax - logDMin));
      const [r, g, b] = penToColor(mm / 1000);
      ctx.fillStyle = `rgb(${r},${g},${b})`;
      ctx.fillRect(legX, pY + i, legW, 1.5);
    }
    ctx.strokeStyle = LC.border;
    ctx.strokeRect(legX, pY, legW, pH);

    ctx.fillStyle = LC.textDim;
    ctx.font = '9px JetBrains Mono, monospace';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    for (const { mm, text } of [
      { mm: 300, text: '30cm' }, { mm: 50, text: '5cm' },
      { mm: 1, text: '1mm' }, { mm: 0.01, text: '~0' },
    ]) {
      const y = mm <= 0.01
        ? pY + pH
        : pY + ((logDMax - Math.log10(mm)) / (logDMax - logDMin)) * pH;
      ctx.fillText(text, legX + legW + 3, y);
    }

    return () => {};
  });
</script>

<section class="calculations">
  <h2>Calculations</h2>
  <p class="subtitle">Physics calculators for game design</p>

  <nav class="sub-tab-bar">
    <button
      class="sub-tab-btn"
      class:active={activeSubTab === 'projectile'}
      onclick={() => activeSubTab = 'projectile'}
    >
      Projectile
    </button>
    <button
      class="sub-tab-btn"
      class:active={activeSubTab === 'laser'}
      onclick={() => activeSubTab = 'laser'}
    >
      Lasers
    </button>
    <button
      class="sub-tab-btn"
      class:active={activeSubTab === 'particle'}
      onclick={() => activeSubTab = 'particle'}
    >
      Particle Beams
    </button>
  </nav>

  <div class="sub-content">
    {#if activeSubTab === 'projectile'}

      <!-- ── Governing Equation ──────────────────────── -->
      <div class="equations-section">
        <h3>Governing Equation</h3>
        <div class="equation-block">
          <div class="equation">
            <span class="eq-var">KE</span> = &frac12; <span class="eq-var">m</span> <span class="eq-var">v</span><sup>2</sup>
          </div>
          <div class="eq-label">Kinetic Energy &mdash; energy of a moving projectile</div>
          <div class="eq-desc">
            <span class="eq-var-sm">KE</span> = kinetic energy (J) &middot;
            <span class="eq-var-sm">m</span> = mass (kg) &middot;
            <span class="eq-var-sm">v</span> = velocity (m/s)
          </div>
        </div>
      </div>

      <!-- ── Calculator ──────────────────────────────── -->
      <div class="calc-panel">
        <div class="calc-grid">

          <!-- Shape -->
          <div class="field-group">
            <label class="field-label">Shape</label>
            <div class="shape-buttons">
              <button class="shape-btn" class:active={shape === 'box'} onclick={() => shape = 'box'}>Box</button>
              <button class="shape-btn" class:active={shape === 'sphere'} onclick={() => shape = 'sphere'}>Sphere</button>
              <button class="shape-btn" class:active={shape === 'rod'} onclick={() => shape = 'rod'}>Rod</button>
            </div>
          </div>

          <!-- Dimensions -->
          <div class="field-group">
            <label class="field-label">Dimensions (m)</label>
            <div class="dim-inputs">
              {#if shape === 'box'}
                <div class="dim-field">
                  <span class="dim-label">X</span>
                  <input type="number" bind:value={dimX} min="0.001" step="0.01" />
                </div>
                <div class="dim-field">
                  <span class="dim-label">Y</span>
                  <input type="number" bind:value={dimY} min="0.001" step="0.01" />
                </div>
                <div class="dim-field">
                  <span class="dim-label">Z</span>
                  <input type="number" bind:value={dimZ} min="0.001" step="0.01" />
                </div>
              {:else if shape === 'sphere'}
                <div class="dim-field">
                  <span class="dim-label">R</span>
                  <input type="number" bind:value={dimX} min="0.001" step="0.01" />
                </div>
              {:else}
                <div class="dim-field">
                  <span class="dim-label">R</span>
                  <input type="number" bind:value={dimX} min="0.001" step="0.01" />
                </div>
                <div class="dim-field">
                  <span class="dim-label">L</span>
                  <input type="number" bind:value={dimY} min="0.001" step="0.01" />
                </div>
              {/if}
            </div>
          </div>

          <!-- Material -->
          <div class="field-group">
            <label class="field-label">Material</label>
            <select bind:value={materialIndex}>
              {#each materials as mat, i}
                <option value={i}>{mat.name} ({mat.density.toLocaleString()} kg/m³)</option>
              {/each}
            </select>
          </div>

          <!-- Speed -->
          <div class="field-group">
            <label class="field-label">Speed</label>
            <div class="speed-row">
              <input type="number" bind:value={speed} min="0" step="100" class="speed-input" />
              <div class="unit-buttons">
                <button class="unit-btn" class:active={speedUnit === 'm/s'} onclick={() => speedUnit = 'm/s'}>m/s</button>
                <button class="unit-btn" class:active={speedUnit === 'km/s'} onclick={() => speedUnit = 'km/s'}>km/s</button>
              </div>
            </div>
          </div>

        </div>

        <!-- ── Results ──────────────────────────────── -->
        <div class="results">
          <div class="result-row">
            <span class="result-label">Volume</span>
            <span class="result-value">{formatVolume(volume)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Mass</span>
            <span class="result-value">{formatMass(mass)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Speed</span>
            <span class="result-value">{speedMs.toLocaleString()} m/s</span>
          </div>
          <div class="result-divider"></div>
          <div class="result-row primary">
            <span class="result-label">Kinetic Energy</span>
            <span class="result-value">{formatEnergy(energy)}</span>
          </div>
        </div>
      </div>

    {/if}

    {#if activeSubTab === 'laser'}

      <!-- ── Governing Equations ───────────────────────── -->
      <div class="equations-section">
        <h3>Governing Equations</h3>
        <div class="equation-block">
          <div class="equation">
            <span class="eq-var">d<sub>spot</sub></span> = 2.44 &middot; <span class="eq-var">&lambda;</span> &middot; <span class="eq-var">R</span> / <span class="eq-var">D</span>
          </div>
          <div class="eq-label">Diffraction-limited spot diameter at range</div>
          <div class="eq-desc">
            <span class="eq-var-sm">&lambda;</span> = wavelength &middot;
            <span class="eq-var-sm">R</span> = range &middot;
            <span class="eq-var-sm">D</span> = aperture diameter
          </div>
        </div>
        <div class="equation-block" style="margin-top: 0.75rem;">
          <div class="equation">
            <span class="eq-var">depth</span> = <span class="eq-var">&alpha;</span> &middot; <span class="eq-var">P</span> &middot; <span class="eq-var">t</span> / (<span class="eq-var">A<sub>spot</sub></span> &middot; <span class="eq-var">&rho;</span> &middot; (<span class="eq-var">c</span>&middot;&Delta;<span class="eq-var">T</span> + <span class="eq-var">L<sub>f</sub></span>))
          </div>
          <div class="eq-label">Penetration depth &mdash; energy-balance melt-through model</div>
          <div class="eq-desc">
            <span class="eq-var-sm">&alpha;</span> = absorption &middot;
            <span class="eq-var-sm">P</span> = power (W) &middot;
            <span class="eq-var-sm">t</span> = time (s) &middot;
            <span class="eq-var-sm">&rho;</span> = density &middot;
            <span class="eq-var-sm">c</span> = specific heat &middot;
            <span class="eq-var-sm">L<sub>f</sub></span> = latent heat of fusion
          </div>
        </div>
      </div>

      <!-- ── Calculator ────────────────────────────────── -->
      <div class="calc-panel">
        <div class="calc-grid">

          <SliderInput label="Aperture (cm)" bind:value={laserAperture} min={5} max={200} step={1} />
          <SliderInput label="Wavelength (nm)" bind:value={laserWavelength} min={200} max={10600} step={1} />
          <SliderInput label="Power ({formatPowerCompact(laserPower)})" bind:value={laserPower} min={0.1} max={100000} step={0.1} log />
          <SliderInput label="Range (km)" bind:value={laserRange} min={1} max={1000} step={1} inputMax={10000} />

        </div>

        <!-- ── Computed values ─────────────────────────── -->
        <div class="results">
          <div class="result-row">
            <span class="result-label">Spot diameter at target</span>
            <span class="result-value">{formatSpot(spotDiameter)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Absorption coeff. (&alpha;)</span>
            <span class="result-value">{(laserAbsorption * 100).toFixed(1)}%</span>
          </div>
          <div class="result-row">
            <span class="result-label">Absorbed power density</span>
            <span class="result-value">{formatPowerDensity(absorbedPowerDensity)}</span>
          </div>
        </div>
      </div>

      <!-- ── Penetration Bar ───────────────────────────── -->
      <div class="calc-panel" style="margin-top: 1rem;">
        <h3 class="bar-title">Steel Plate Penetration (up to {maxPlate * 100} cm)</h3>

        <div class="pen-bar-wrapper">
          <div class="pen-bar-track">
            {#each [3, 2, 1, 0] as i}
              <div
                class="pen-fill"
                style="width: {penPcts[i]}%; background: {durColors[i]}33; border-right: 2px solid {durColors[i]};"
              ></div>
            {/each}

            {#each durations as _, i}
              {#if penPcts[i] > 0 && penPcts[i] <= 100}
                <div class="pen-marker" style="left: {penPcts[i]}%;">
                  <span class="pen-marker-label" style="color: {durColors[i]};">{durLabels[i]}</span>
                </div>
              {/if}
            {/each}
          </div>

          <!-- Scale -->
          <div class="pen-scale">
            <span>0</span>
            <span>10 cm</span>
            <span>20 cm</span>
            <span>30 cm</span>
          </div>
        </div>

        <!-- Per-duration results -->
        <div class="pen-results">
          {#each durations as t, i}
            <div class="pen-result-row">
              <span class="pen-dur" style="color: {durColors[i]};">{durLabels[i]}</span>
              <span class="pen-depth">{formatDepth(penDepths[i])}</span>
              <span class="pen-status" style="color: {penDepths[i] >= maxPlate ? '#68d391' : LC.textDim};">
                {penDepths[i] >= maxPlate ? 'PENETRATES' : penDepths[i] > 0.001 ? 'partial' : 'negligible'}
              </span>
            </div>
          {/each}
        </div>
      </div>

      <!-- ── Continuous Chart ──────────────────────────── -->
      <div class="chart-section" style="margin-top: 1rem;">
        <canvas bind:this={laserCanvas}></canvas>
      </div>

      <!-- ── Range vs Power Heatmap ────────────────────── -->
      <div class="chart-section heatmap-wrap" style="margin-top: 1rem;">
        <canvas bind:this={heatmapCanvas}></canvas>
      </div>

    {/if}

    {#if activeSubTab === 'particle'}

      <!-- ── Governing Equations ───────────────────────── -->
      <div class="equations-section">
        <h3>Governing Equations</h3>
        <div class="equation-block">
          <div class="equation">
            <span class="eq-var">d<sub>spot</sub></span> = 2(<span class="eq-var">r<sub>0</sub></span> + <span class="eq-var">&theta;</span> &middot; <span class="eq-var">R</span> + <span class="eq-var">K</span> &middot; <span class="eq-var">R</span><sup>2</sup> / 2<span class="eq-var">r<sub>0</sub></span>)
          </div>
          <div class="eq-label">Spot diameter at range &mdash; geometric + space-charge expansion</div>
          <div class="eq-desc">
            <span class="eq-var-sm">r<sub>0</sub></span> = initial beam radius (2 mm) &middot;
            <span class="eq-var-sm">&theta;</span> = half-angle divergence &middot;
            <span class="eq-var-sm">R</span> = range &middot;
            <span class="eq-var-sm">K</span> = perveance (0 for neutral beams)
          </div>
        </div>
        <div class="equation-block" style="margin-top: 0.75rem;">
          <div class="equation">
            <span class="eq-var">K</span> = 2<span class="eq-var">I</span> / (<span class="eq-var">I<sub>A</sub></span> &middot; (<span class="eq-var">&beta;&gamma;</span>)<sup>3</sup>)
          </div>
          <div class="eq-label">Generalized perveance &mdash; space-charge strength (charged beams only)</div>
          <div class="eq-desc">
            <span class="eq-var-sm">I</span> = beam current (P/E) &middot;
            <span class="eq-var-sm">I<sub>A</sub></span> = Alfv&eacute;n current (31.3 MA for protons) &middot;
            <span class="eq-var-sm">&beta;&gamma;</span> = relativistic momentum factor
          </div>
        </div>
        <div class="equation-block" style="margin-top: 0.75rem;">
          <div class="equation">
            <span class="eq-var">depth</span> = <span class="eq-var">&eta;</span> &middot; <span class="eq-var">P</span> &middot; <span class="eq-var">t</span> / (<span class="eq-var">A<sub>spot</sub></span> &middot; <span class="eq-var">&rho;</span> &middot; (<span class="eq-var">c</span>&middot;&Delta;<span class="eq-var">T</span> + <span class="eq-var">L<sub>f</sub></span>))
          </div>
          <div class="eq-label">Penetration depth &mdash; energy-balance melt-through model</div>
          <div class="eq-desc">
            <span class="eq-var-sm">&eta;</span> = deposition efficiency (60%) &middot;
            <span class="eq-var-sm">P</span> = beam power &middot;
            <span class="eq-var-sm">t</span> = time &middot;
            <span class="eq-var-sm">&rho;</span> = density &middot;
            <span class="eq-var-sm">c</span> = specific heat &middot;
            <span class="eq-var-sm">L<sub>f</sub></span> = latent heat of fusion
          </div>
        </div>
      </div>

      <!-- ── Calculator ──────────────────────────────────── -->
      <div class="calc-panel">
        <div class="field-group" style="margin-bottom: 1.25rem;">
          <label class="field-label">Beam Type</label>
          <div class="shape-buttons">
            <button class="shape-btn" class:active={beamType === 'neutral'} onclick={() => beamType = 'neutral'}>Neutral</button>
            <button class="shape-btn" class:active={beamType === 'charged'} onclick={() => beamType = 'charged'}>Charged</button>
          </div>
        </div>

        <div class="calc-grid">
          <SliderInput label="Divergence ({formatDivergence(pbDivergence)})" bind:value={pbDivergence} min={0.5} max={5000} step={0.1} log />
          <SliderInput label="Particle Energy ({formatParticleEnergy(pbEnergy)})" bind:value={pbEnergy} min={1} max={10000} step={1} log />
          <SliderInput label="Power ({formatPowerCompact(pbPower)})" bind:value={pbPower} min={0.1} max={100000} step={0.1} log />
          <SliderInput label="Range ({formatRangeLabel(pbRange)})" bind:value={pbRange} min={0.001} max={100} step={0.001} log inputMax={1000} />
        </div>

        <!-- ── Computed values ─────────────────────────── -->
        <div class="results">
          <div class="result-row">
            <span class="result-label">Spot diameter at target</span>
            <span class="result-value">{formatSpot(pbSpotDiameter)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Beam current</span>
            <span class="result-value">{formatCurrent(pbCurrent)}</span>
          </div>
          {#if beamType === 'charged'}
            <div class="result-row">
              <span class="result-label">Generalized perveance (K)</span>
              <span class="result-value">{pbPerveance.toExponential(2)}</span>
            </div>
          {/if}
          <div class="result-row">
            <span class="result-label">Deposition efficiency (&eta;)</span>
            <span class="result-value">{(PB_DEPOSITION * 100).toFixed(0)}%</span>
          </div>
          <div class="result-row">
            <span class="result-label">Absorbed power density</span>
            <span class="result-value">{formatPowerDensity(pbAbsorbedPowerDensity)}</span>
          </div>
        </div>
      </div>

      <!-- ── Penetration Bar ───────────────────────────── -->
      <div class="calc-panel" style="margin-top: 1rem;">
        <h3 class="bar-title">Steel Plate Penetration (up to {maxPlate * 100} cm)</h3>

        <div class="pen-bar-wrapper">
          <div class="pen-bar-track">
            {#each [3, 2, 1, 0] as i}
              <div
                class="pen-fill"
                style="width: {pbPenPcts[i]}%; background: {durColors[i]}33; border-right: 2px solid {durColors[i]};"
              ></div>
            {/each}

            {#each durations as _, i}
              {#if pbPenPcts[i] > 0 && pbPenPcts[i] <= 100}
                <div class="pen-marker" style="left: {pbPenPcts[i]}%;">
                  <span class="pen-marker-label" style="color: {durColors[i]};">{durLabels[i]}</span>
                </div>
              {/if}
            {/each}
          </div>

          <div class="pen-scale">
            <span>0</span>
            <span>10 cm</span>
            <span>20 cm</span>
            <span>30 cm</span>
          </div>
        </div>

        <div class="pen-results">
          {#each durations as t, i}
            <div class="pen-result-row">
              <span class="pen-dur" style="color: {durColors[i]};">{durLabels[i]}</span>
              <span class="pen-depth">{formatDepth(pbPenDepths[i])}</span>
              <span class="pen-status" style="color: {pbPenDepths[i] >= maxPlate ? '#68d391' : LC.textDim};">
                {pbPenDepths[i] >= maxPlate ? 'PENETRATES' : pbPenDepths[i] > 0.001 ? 'partial' : 'negligible'}
              </span>
            </div>
          {/each}
        </div>
      </div>

      <!-- ── Continuous Chart ──────────────────────────── -->
      <div class="chart-section" style="margin-top: 1rem;">
        <canvas bind:this={pbChartCanvas}></canvas>
      </div>

      <!-- ── Range vs Power Heatmap ────────────────────── -->
      <div class="chart-section heatmap-wrap" style="margin-top: 1rem;">
        <canvas bind:this={pbHeatmapCanvas}></canvas>
      </div>

    {/if}
  </div>
</section>

<style>
  /* ── Layout ──────────────────────────────────────── */
  .calculations h2 {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1.3rem;
    color: var(--accent);
    margin-bottom: 0.25rem;
  }

  .subtitle {
    color: var(--text-dim);
    font-size: 0.85rem;
    margin-bottom: 1.25rem;
  }

  .sub-tab-bar {
    display: flex;
    gap: 0;
    border-bottom: 1px solid var(--border);
    margin-bottom: 1.5rem;
  }

  .sub-tab-btn {
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    color: var(--text-dim);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.8rem;
    font-weight: 500;
    padding: 0.5rem 1rem;
    cursor: pointer;
    transition: color 0.2s, border-color 0.2s;
  }

  .sub-tab-btn:hover {
    color: var(--text);
  }

  .sub-tab-btn.active {
    color: var(--orange);
    border-bottom-color: var(--orange);
  }

  .sub-content {
    min-height: 200px;
  }

  /* ── Equations ───────────────────────────────────── */
  .equations-section {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem 1.5rem;
    margin-bottom: 1.5rem;
  }

  .equations-section h3 {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1rem;
    color: var(--text);
    margin-bottom: 1rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .equation-block {
    margin-bottom: 0;
  }

  .equation {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1.15rem;
    color: var(--text);
    margin-bottom: 0.2rem;
  }

  .eq-var {
    color: var(--accent);
    font-weight: 600;
  }

  .eq-var-sm {
    color: var(--accent);
    font-family: 'JetBrains Mono', monospace;
    font-weight: 600;
    font-size: 0.85rem;
  }

  .eq-label {
    color: var(--text-dim);
    font-size: 0.8rem;
    font-style: italic;
    margin-bottom: 0.15rem;
  }

  .eq-desc {
    color: var(--text-dim);
    font-size: 0.78rem;
    line-height: 1.6;
  }

  /* ── Calculator Panel ───────────────────────────── */
  .calc-panel {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.5rem;
  }

  .calc-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.25rem;
    margin-bottom: 1.5rem;
  }

  .field-group {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
    min-width: 0;
  }

  .field-label {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.75rem;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  /* ── Shape buttons ──────────────────────────────── */
  .shape-buttons, .unit-buttons {
    display: flex;
    gap: 0;
    border: 1px solid var(--border);
    border-radius: 6px;
    overflow: hidden;
  }

  .shape-btn, .unit-btn {
    flex: 1;
    background: var(--bg);
    border: none;
    border-right: 1px solid var(--border);
    color: var(--text-dim);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.8rem;
    padding: 0.45rem 0.75rem;
    cursor: pointer;
    transition: background 0.15s, color 0.15s;
  }

  .shape-btn:last-child, .unit-btn:last-child {
    border-right: none;
  }

  .shape-btn:hover, .unit-btn:hover {
    color: var(--text);
    background: var(--surface2);
  }

  .shape-btn.active, .unit-btn.active {
    background: var(--accent);
    color: var(--bg);
    font-weight: 600;
  }

  /* ── Dimension inputs ───────────────────────────── */
  .dim-inputs {
    display: flex;
    gap: 0.5rem;
  }

  .dim-field {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    flex: 1;
  }

  .dim-label {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.75rem;
    color: var(--accent);
    font-weight: 600;
    min-width: 1rem;
    text-align: center;
  }

  input[type="number"], select {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.85rem;
    padding: 0.45rem 0.6rem;
    width: 100%;
    outline: none;
    transition: border-color 0.15s;
  }

  input[type="number"]:focus, select:focus {
    border-color: var(--accent);
  }

  select {
    cursor: pointer;
  }

  /* ── Speed row ──────────────────────────────────── */
  .speed-row {
    display: flex;
    gap: 0.5rem;
  }

  .speed-input {
    flex: 1;
  }

  .unit-buttons {
    flex-shrink: 0;
    width: 120px;
  }

  /* ── Results ────────────────────────────────────── */
  .results {
    border-top: 1px solid var(--border);
    padding-top: 1.25rem;
  }

  .result-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.35rem 0;
  }

  .result-label {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.8rem;
    color: var(--text-dim);
  }

  .result-value {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.9rem;
    color: var(--text);
  }

  .result-divider {
    border-top: 1px solid var(--border);
    margin: 0.5rem 0;
  }

  .result-row.primary .result-label {
    color: var(--accent);
    font-weight: 600;
    font-size: 0.85rem;
  }

  .result-row.primary .result-value {
    color: var(--accent);
    font-weight: 700;
    font-size: 1.1rem;
  }

  /* ── Penetration Bar ──────────────────────────────── */
  .bar-title {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.85rem;
    color: var(--text);
    margin-bottom: 1rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .pen-bar-wrapper {
    margin-bottom: 1.25rem;
  }

  .pen-bar-track {
    position: relative;
    height: 36px;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 6px;
    overflow: hidden;
  }

  .pen-fill {
    position: absolute;
    top: 0;
    left: 0;
    height: 100%;
    transition: width 0.3s ease;
  }

  .pen-marker {
    position: absolute;
    top: 0;
    height: 100%;
    display: flex;
    align-items: flex-start;
    transform: translateX(-50%);
    pointer-events: none;
  }

  .pen-marker-label {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    font-weight: 600;
    white-space: nowrap;
    padding: 2px 4px;
    background: var(--bg);
    border-radius: 3px;
  }

  .pen-scale {
    display: flex;
    justify-content: space-between;
    padding: 0.3rem 0 0;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    color: var(--text-dim);
  }

  /* ── Per-duration results ─────────────────────────── */
  .pen-results {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 0.5rem;
  }

  .pen-result-row {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.15rem;
    padding: 0.5rem;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 6px;
  }

  .pen-dur {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .pen-depth {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.9rem;
    color: var(--text);
    font-weight: 600;
  }

  .pen-status {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  /* ── Chart section ────────────────────────────────── */
  .chart-section {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem;
  }

  .heatmap-wrap canvas {
    width: 100%;
    height: auto;
  }

  /* ── Responsive ─────────────────────────────────── */
  @media (max-width: 700px) {
    .calc-grid {
      grid-template-columns: 1fr;
    }
    .pen-results {
      grid-template-columns: repeat(2, 1fr);
    }
  }
</style>
