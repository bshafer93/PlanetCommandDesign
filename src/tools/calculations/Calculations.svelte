<script lang="ts">
  import { Chart, registerables } from 'chart.js';
  import annotationPlugin from 'chartjs-plugin-annotation';
  import Plotly from 'plotly.js-gl3d-dist-min';
  import SliderInput from '../../components/SliderInput.svelte';
  import materialsDB from './data/materials-database.json';
  Chart.register(...registerables, annotationPlugin);

  // ── Materials database: filtered lists ────────────
  const projCategories = new Set(['metal', 'metalloid', 'alloy', 'ceramic', 'carbon', 'composite']);
  const projectileMaterials = materialsDB.materials.filter(
    m => projCategories.has(m.category) && m.density_kgm3 != null
  );
  const targetMaterials = materialsDB.materials.filter(
    m => projCategories.has(m.category)
      && m.density_kgm3 != null
      && (m as any).specificHeat_JkgK != null
      && (m as any).meltingPoint_K != null
      && (m as any).latentHeatFusion_Jkg != null
  );

  type SubTab = 'projectile' | 'laser' | 'particle';
  let activeSubTab: SubTab = $state('projectile');

  // ── Shape types ────────────────────────────────────
  type Shape = 'box' | 'sphere' | 'rod';
  let shape: Shape = $state('box');

  // Dimensions in meters
  let dimX = $state(0.1);
  let dimY = $state(0.1);
  let dimZ = $state(0.1);

  // ── Projectile material (from DB) ──────────────────
  let projMaterialIndex = $state(projectileMaterials.findIndex(m => m.name === 'Steel, AISI 4130') ?? 0);

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

  let density = $derived(projectileMaterials[projMaterialIndex].density_kgm3);
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

  // ── Viz panel drag-and-drop reordering ──────────────
  let laserVizOrder = $state([0, 1, 2]);
  let pbVizOrder = $state([0, 1, 2, 3, 4, 5]);

  let dragSource: { group: string; id: number } | null = null;
  let dragOverId: { group: string; id: number } | null = $state(null);

  function vizDragStart(e: DragEvent, group: string, id: number) {
    dragSource = { group, id };
    e.dataTransfer!.effectAllowed = 'move';
    e.dataTransfer!.setData('text/plain', ''); // required for Firefox
    (e.target as HTMLElement).closest('.viz-toggle')!.classList.add('viz-dragging');
  }
  function vizDragEnd(e: DragEvent) {
    (e.target as HTMLElement).closest('.viz-toggle')?.classList.remove('viz-dragging');
    dragSource = null;
    dragOverId = null;
  }
  function vizDragOver(e: DragEvent, group: string, id: number) {
    if (!dragSource || dragSource.group !== group || dragSource.id === id) return;
    e.preventDefault();
    e.dataTransfer!.dropEffect = 'move';
    dragOverId = { group, id };
  }
  function vizDragLeave() {
    dragOverId = null;
  }
  function vizDrop(e: DragEvent, group: string, targetId: number) {
    e.preventDefault();
    if (!dragSource || dragSource.group !== group || dragSource.id === targetId) return;

    const order = group === 'laser' ? [...laserVizOrder] : [...pbVizOrder];
    const fromIdx = order.indexOf(dragSource.id);
    const toIdx = order.indexOf(targetId);
    order.splice(fromIdx, 1);
    order.splice(toIdx, 0, dragSource.id);

    if (group === 'laser') laserVizOrder = order;
    else if (group === 'pb') pbVizOrder = order;

    dragSource = null;
    dragOverId = null;
  }

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

  // ── Target material (shared by laser + particle beam) ──
  const defaultTargetIdx = targetMaterials.findIndex(m => m.name === 'Steel, AISI 4130');
  let targetMaterialIndex = $state(defaultTargetIdx >= 0 ? defaultTargetIdx : 0);
  let plateThickness = $state(30); // cm

  let targetMaterial = $derived(targetMaterials[targetMaterialIndex]);
  let energyPerVolume = $derived(
    targetMaterial.density_kgm3 * (
      (targetMaterial as any).specificHeat_JkgK * ((targetMaterial as any).meltingPoint_K - 300)
      + (targetMaterial as any).latentHeatFusion_Jkg
    )
  ); // J/m³
  let maxPlate = $derived(plateThickness / 100); // cm → m

  // Penetration depth (m) = absorbed_power_density × time / energy_per_volume
  function calcPen(apd: number, t: number, epv: number): number {
    return apd * t / epv;
  }
  const durations = [1, 5, 10, 30];
  const durColors = [LC.accent, LC.green, LC.orange, LC.red];
  const durLabels = ['1 s', '5 s', '10 s', '30 s'];

  let laserPenRate = $derived(absorbedPowerDensity / energyPerVolume); // m/s
  let penDepths = $derived(durations.map(t => calcPen(absorbedPowerDensity, t, energyPerVolume)));
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

  function formatPenRate(ms: number): string {
    if (!isFinite(ms) || isNaN(ms) || ms <= 0) return '—';
    if (ms >= 1) return ms.toFixed(2) + ' m/s';
    if (ms >= 0.01) return (ms * 100).toFixed(2) + ' cm/s';
    if (ms >= 0.001) return (ms * 1000).toFixed(2) + ' mm/s';
    return (ms * 1e6).toFixed(1) + ' μm/s';
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
  function calcPenStandalone(powerMW: number, rangeKm: number, apertCm: number, wavNm: number, epv: number): number {
    const abs = getAbsorption(wavNm);
    const spotD = 2.44 * (wavNm * 1e-9) * (rangeKm * 1000) / (apertCm / 100);
    const spotA = Math.PI * (spotD / 2) ** 2;
    const apd = abs * (powerMW * 1e6) / spotA;
    return apd / epv; // 1-second impulse
  }

  // ── Charts ─────────────────────────────────────────
  let laserCanvas = $state<HTMLCanvasElement>();
  let heatmapCanvas = $state<HTMLCanvasElement>();
  let laserChart: Chart | undefined;
  let laserChartCanvas: HTMLCanvasElement | undefined;

  $effect(() => {
    if (!laserCanvas || activeSubTab !== 'laser') {
      if (laserChart) { laserChart.destroy(); laserChart = undefined; laserChartCanvas = undefined; }
      return;
    }
    const apd = absorbedPowerDensity;
    const epv = energyPerVolume;
    const mp = maxPlate;
    const matName = targetMaterial.name;
    const numPoints = 200;
    const maxTime = 30;
    const times: number[] = [];
    const depths: number[] = [];
    for (let i = 0; i <= numPoints; i++) {
      const t = (i / numPoints) * maxTime;
      times.push(t);
      depths.push(Math.min(calcPen(apd, t, epv), mp));
    }

    const labels = times.map(t => t.toFixed(1));
    const depthsMm = depths.map(d => d * 1000);
    const plateLine = times.map(() => mp * 1000);
    const yMax = Math.max(mp * 1000, depths[depths.length - 1] * 1000 * 1.1);
    const titleText = `${matName} Penetration vs Exposure Time`;
    const plateLabel = `Plate Thickness (${(mp * 1000).toFixed(0)}mm)`;

    if (laserChart && laserChartCanvas === laserCanvas) {
      laserChart.data.labels = labels;
      laserChart.data.datasets[0].data = depthsMm;
      laserChart.data.datasets[1].data = plateLine;
      laserChart.data.datasets[1].label = plateLabel;
      laserChart.options.scales!.y!.max = yMax;
      (laserChart.options.plugins!.title as any).text = titleText;
      laserChart.options.scales!.x!.ticks!.callback = (_, i) => {
        const t = times[i as number];
        return t !== undefined && t % 5 === 0 ? t + 's' : '';
      };
      laserChart.update('none');
    } else {
      laserChart?.destroy();
      laserChart = new Chart(laserCanvas, {
        type: 'line',
        data: {
          labels,
          datasets: [
            {
              label: 'Penetration Depth',
              data: depthsMm,
              borderColor: LC.accent,
              backgroundColor: LC.accent + '22',
              fill: true,
              tension: 0.3,
              pointRadius: 0,
            },
            {
              label: plateLabel,
              data: plateLine,
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
              max: yMax,
            },
          },
          plugins: {
            title: {
              display: true,
              text: titleText,
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
      laserChartCanvas = laserCanvas;
    }
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
    const epv = energyPerVolume;

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
        const pen = calcPenStandalone(pMW, rKm, apert, wav, epv);
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
    const curPen = calcPenStandalone(curPower, curRange, apert, wav, epv);
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

  type ParticleSubTab = 'combat' | 'accelerator';
  let particleSubTab: ParticleSubTab = $state('combat');

  type PBDivergence = 'standard' | 'precision';
  let pbDivChoice: PBDivergence = $state('precision');
  const PB_DIV_OPTIONS = { standard: 5, precision: 0.5 } as const; // μrad
  let pbDivergence = $derived(PB_DIV_OPTIONS[pbDivChoice]);

  let pbAccelLength = $state(10);      // m — accelerator length
  let pbPower = $state(1);             // MW (beam power)
  let pbRange = $state(1);             // km

  const PB_DEPOSITION = 0.60;          // 60% deposition efficiency
  let pbDiameter = $state(5);          // mm — beam diameter
  const PROTON_REST_MASS_MEV = 938.272;
  const ALFVEN_CURRENT_PROTON = 3.13e7; // ~31.3 MA
  const PB_GRADIENT_MIN = 1;           // MV/m
  const PB_GRADIENT_MAX = 100;         // MV/m
  let pbGradient = $state(20);         // MV/m — user-controlled gradient

  let pbR0m = $derived(pbDiameter / 2 / 1000); // diameter mm → radius m

  // ── Auto-optimize gradient for best penetration at current range ──
  function pbPenForGradient(gradient: number): number {
    const ke = gradient * pbAccelLength; // MeV
    if (ke < 1) return 0;
    const gamma = 1 + ke / PROTON_REST_MASS_MEV;
    const beta = Math.sqrt(1 - 1 / (gamma * gamma));
    const bg = beta * gamma;
    const current = (pbPower * 1e6) / (ke * 1e6); // A
    const K = (2 * current) / (ALFVEN_CURRENT_PROTON * Math.pow(bg, 3));
    const theta = pbDivergence * 1e-6;
    const z = pbRange * 1000;
    const spotR = pbSpotRadiusAt(z, theta, K, pbR0m);
    const area = Math.PI * spotR * spotR;
    const apd = PB_DEPOSITION * (pbPower * 1e6) / area;
    return apd / energyPerVolume; // 1-second penetration depth
  }

  let pbOptimalGradient = $derived.by(() => {
    let bestG = PB_GRADIENT_MIN;
    let bestPen = 0;
    for (let g = PB_GRADIENT_MIN; g <= PB_GRADIENT_MAX; g *= 1.05) {
      const pen = pbPenForGradient(g);
      if (pen > bestPen) { bestPen = pen; bestG = g; }
    }
    const lo = Math.max(PB_GRADIENT_MIN, bestG / 1.1);
    const hi = Math.min(PB_GRADIENT_MAX, bestG * 1.1);
    for (let g = lo; g <= hi; g += 0.1) {
      const pen = pbPenForGradient(g);
      if (pen > bestPen) { bestPen = pen; bestG = g; }
    }
    return Math.round(bestG * 10) / 10;
  });

  let pbEnergy = $derived(pbGradient * pbAccelLength); // MeV

  let pbGamma = $derived(1 + pbEnergy / PROTON_REST_MASS_MEV);
  let pbBeta = $derived(Math.sqrt(1 - 1 / (pbGamma * pbGamma)));
  let pbBetaGamma = $derived(pbBeta * pbGamma);
  let pbCurrent = $derived((pbPower * 1e6) / (pbEnergy * 1e6)); // Amperes

  let pbPerveance = $derived(
    (2 * pbCurrent) / (ALFVEN_CURRENT_PROTON * Math.pow(pbBetaGamma, 3))
  );

  function pbSpotRadiusAt(z_m: number, theta_rad: number, K: number, r0: number): number {
    if (K === 0) return r0 + theta_rad * z_m;
    return r0 + theta_rad * z_m + (K / (2 * r0)) * z_m * z_m;
  }

  let pbRangeM = $derived(pbRange * 1000);
  let pbTheta = $derived(pbDivergence * 1e-6);
  let pbSpotRadius = $derived(pbSpotRadiusAt(pbRangeM, pbTheta, pbPerveance, pbR0m));
  let pbSpotDiameter = $derived(2 * pbSpotRadius);
  let pbSpotArea = $derived(Math.PI * pbSpotRadius * pbSpotRadius);
  let pbAbsorbedPowerDensity = $derived(PB_DEPOSITION * (pbPower * 1e6) / pbSpotArea);

  let pbPenRate = $derived(pbAbsorbedPowerDensity / energyPerVolume); // m/s
  let pbPenDepths = $derived(durations.map(t => calcPen(pbAbsorbedPowerDensity, t, energyPerVolume)));
  let pbPenPcts = $derived(pbPenDepths.map(d => Math.min(d / maxPlate * 100, 100)));

  function calcPenPBStandalone(powerMW: number, rangeKm: number, divUrad: number, energyMeV: number, r0_m: number, epv: number): number {
    const z = rangeKm * 1000;
    const theta = divUrad * 1e-6;
    const gamma = 1 + energyMeV / PROTON_REST_MASS_MEV;
    const beta = Math.sqrt(1 - 1 / (gamma * gamma));
    const bg = beta * gamma;
    const current = (powerMW * 1e6) / (energyMeV * 1e6);
    const K = (2 * current) / (ALFVEN_CURRENT_PROTON * Math.pow(bg, 3));
    const spotR = pbSpotRadiusAt(z, theta, K, r0_m);
    const area = Math.PI * spotR * spotR;
    const apd = PB_DEPOSITION * (powerMW * 1e6) / area;
    return apd / epv;
  }

  // Spot radius at range (standalone, for heatmap/3D)
  function pbSpotRadiusAtStandalone(rangeKm: number, divUrad: number, energyMeV: number, powerMW: number, r0_m: number): number {
    const z = rangeKm * 1000;
    const theta = divUrad * 1e-6;
    const gamma = 1 + energyMeV / PROTON_REST_MASS_MEV;
    const beta = Math.sqrt(1 - 1 / (gamma * gamma));
    const bg = beta * gamma;
    const current = (powerMW * 1e6) / (energyMeV * 1e6);
    const K = (2 * current) / (ALFVEN_CURRENT_PROTON * Math.pow(bg, 3));
    return pbSpotRadiusAt(z, theta, K, r0_m);
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

  // ── Feasibility checks (physics limits) ───────────
  // Implied geometric emittance: ε = r₀ · θ
  let pbImpliedEmittance = $derived(pbR0m * pbTheta); // m·rad
  // Normalized emittance: εₙ = βγ · ε
  let pbNormEmittance = $derived(pbBetaGamma * pbImpliedEmittance); // m·rad

  // State-of-art emittance thresholds (proton beams)
  const EMITTANCE_BEST = 5e-8;   // 0.05 μm·rad — theoretical best
  const EMITTANCE_SOTA = 2e-7;   // 0.2 μm·rad — high-brightness injector
  const EMITTANCE_TYPICAL = 1e-6; // 1 μm·rad — typical RF ion source

  type FeasibilityLevel = 'ok' | 'warning' | 'error';
  interface FeasibilityCheck {
    level: FeasibilityLevel;
    label: string;
    detail: string;
  }

  let pbFeasibility = $derived.by((): FeasibilityCheck[] => {
    const checks: FeasibilityCheck[] = [];
    const eps_n = pbNormEmittance;
    const theta = pbTheta;
    const rangeM = pbRangeM;
    const spotR = pbSpotRadius;

    // 1) Emittance feasibility — is the implied εₙ achievable?
    if (eps_n < EMITTANCE_BEST) {
      checks.push({
        level: 'error',
        label: 'Emittance: beyond theoretical limits',
        detail: `Required εₙ = ${(eps_n * 1e6).toExponential(1)} μm·rad — below best theoretical (0.05 μm·rad). This divergence is not physically achievable.`,
      });
    } else if (eps_n < EMITTANCE_SOTA) {
      checks.push({
        level: 'warning',
        label: 'Emittance: requires cutting-edge source',
        detail: `Required εₙ = ${(eps_n * 1e6).toFixed(3)} μm·rad — needs a high-brightness injector (state-of-art ~0.2 μm·rad).`,
      });
    } else if (eps_n < EMITTANCE_TYPICAL) {
      checks.push({
        level: 'ok',
        label: 'Emittance: achievable with good source',
        detail: `Required εₙ = ${(eps_n * 1e6).toFixed(3)} μm·rad — within reach of modern RF ion sources (~1 μm·rad).`,
      });
    }

    // 2) Max range check: L_max = r_spot · r₀ / ε
    // For a "useful" spot (e.g. 5cm radius = 10cm diameter), what's the max range?
    const usefulSpotR = 0.05; // 5cm — reasonable weapon spot
    const maxRange = usefulSpotR * pbR0m / pbImpliedEmittance;
    if (rangeM > maxRange * 1.5) {
      checks.push({
        level: 'error',
        label: 'Range: exceeds physics limit',
        detail: `Max range for a 10cm spot = ${formatRangeLabel(maxRange / 1000)}. At ${formatRangeLabel(pbRange)} the beam cannot be focused — no amount of power fixes this.`,
      });
    } else if (rangeM > maxRange * 0.8) {
      checks.push({
        level: 'warning',
        label: 'Range: near feasibility limit',
        detail: `Max range for a 10cm spot ≈ ${formatRangeLabel(maxRange / 1000)}. Current range is close to the hard emittance limit.`,
      });
    }

    // 3) Spot size check — is the beam too spread to be useful?
    if (spotR > 1.0) {
      checks.push({
        level: 'error',
        label: 'Spot: beam fully dispersed',
        detail: `Spot diameter = ${(spotR * 2).toFixed(1)} m — beam is too spread to concentrate energy on a target.`,
      });
    } else if (spotR > 0.1) {
      checks.push({
        level: 'warning',
        label: 'Spot: beam significantly spread',
        detail: `Spot diameter = ${(spotR * 2 * 100).toFixed(0)} cm — energy density is very low at this spread.`,
      });
    }

    // 4) Space charge severity
    const K = pbPerveance;
    if (K > 1e-2) {
      checks.push({
        level: 'error',
        label: 'Space charge: catastrophic',
        detail: `Perveance K = ${K.toExponential(1)} — beam blows apart rapidly. Increase particle energy or reduce current.`,
      });
    } else if (K > 1e-4) {
      checks.push({
        level: 'warning',
        label: 'Space charge: severe',
        detail: `Perveance K = ${K.toExponential(1)} — dominates beam expansion. Consider higher particle energy or lower current.`,
      });
    } else if (K > 1e-6) {
      checks.push({
        level: 'ok',
        label: 'Space charge: moderate',
        detail: `Perveance K = ${K.toExponential(1)} — noticeable but partially manageable.`,
      });
    }

    // 5) Geometric divergence vs desired spot: θ ≤ r/L
    // Check if the divergence alone (ignoring space charge) gives a reasonable spot
    const geoSpotR = pbR0m + theta * rangeM;
    const geoMaxTheta = usefulSpotR / rangeM;
    if (theta > geoMaxTheta * 2) {
      checks.push({
        level: 'error',
        label: 'Divergence: too high for this range',
        detail: `Need θ ≤ ${(geoMaxTheta * 1e6).toFixed(1)} μrad for 10cm spot at ${formatRangeLabel(pbRange)}. Current: ${formatDivergence(pbDivergence)}.`,
      });
    } else if (theta > geoMaxTheta) {
      checks.push({
        level: 'warning',
        label: 'Divergence: marginal for this range',
        detail: `For a 10cm spot at ${formatRangeLabel(pbRange)}, need θ ≤ ${(geoMaxTheta * 1e6).toFixed(1)} μrad. Current: ${formatDivergence(pbDivergence)}.`,
      });
    }

    return checks;
  });

  function formatParticleEnergy(mev: number): string {
    if (mev >= 1000) return (mev / 1000).toFixed(1) + ' GeV';
    return mev.toFixed(0) + ' MeV';
  }

  function formatRangeLabel(km: number): string {
    if (km < 1) return (km * 1000).toFixed(0) + ' m';
    return km.toFixed(km < 10 ? 1 : 0) + ' km';
  }

  // ── Emittance vs Beam Diameter chart ─────────────────
  let emittanceChart: Chart | undefined;
  let emittanceChartCanvas: HTMLCanvasElement | undefined;

  const emittanceAnnotations = {
    physicsFloor: {
      type: 'line' as const, yMin: 0.05, yMax: 0.05,
      borderColor: LC.red, borderWidth: 1.5, borderDash: [6, 3],
      label: { display: true, content: 'Physics floor (0.05)', position: 'start' as const, color: LC.red, backgroundColor: 'transparent', font: { ...chartFont, size: 10 } },
    },
    sotaInjector: {
      type: 'line' as const, yMin: 0.2, yMax: 0.2,
      borderColor: '#ed8936', borderWidth: 1.5, borderDash: [6, 3],
      label: { display: true, content: 'SOTA injector (0.2)', position: 'start' as const, color: '#ed8936', backgroundColor: 'transparent', font: { ...chartFont, size: 10 } },
    },
    typicalRF: {
      type: 'line' as const, yMin: 1.0, yMax: 1.0,
      borderColor: '#68d391', borderWidth: 1.5, borderDash: [6, 3],
      label: { display: true, content: 'Typical RF source (1.0)', position: 'start' as const, color: '#68d391', backgroundColor: 'transparent', font: { ...chartFont, size: 10 } },
    },
  };

  $effect(() => {
    if (!pbEmittanceCanvas || activeSubTab !== 'particle') {
      if (emittanceChart) { emittanceChart.destroy(); emittanceChart = undefined; emittanceChartCanvas = undefined; }
      return;
    }

    const bg = pbBetaGamma;
    const curDiam = pbDiameter;
    const curDiv = pbDivergence;
    const curEpsN = pbNormEmittance;

    const precisionPts: { x: number; y: number }[] = [];
    const standardPts: { x: number; y: number }[] = [];
    for (let d = 5; d <= 100; d *= 1.04) {
      const r0 = d / 2 / 1000;
      precisionPts.push({ x: d, y: bg * r0 * 0.5e-6 * 1e6 });
      standardPts.push({ x: d, y: bg * r0 * 5e-6 * 1e6 });
    }

    const titleText = `Emittance vs Beam Diameter (βγ = ${bg.toFixed(2)}, KE = ${formatParticleEnergy(pbEnergy)})`;
    const curLabel = `Current (⌀${curDiam}mm, ${formatDivergence(curDiv)})`;
    const curPoint = [{ x: curDiam, y: curEpsN * 1e6 }];

    if (emittanceChart && emittanceChartCanvas === pbEmittanceCanvas) {
      emittanceChart.data.datasets[0].data = precisionPts;
      emittanceChart.data.datasets[1].data = standardPts;
      emittanceChart.data.datasets[2].data = curPoint;
      emittanceChart.data.datasets[2].label = curLabel;
      (emittanceChart.options.plugins!.title as any).text = titleText;
      emittanceChart.update('none');
    } else {
      emittanceChart?.destroy();
      emittanceChart = new Chart(pbEmittanceCanvas, {
        type: 'line',
        data: {
          datasets: [
            { label: 'θ = 0.5 μrad (Precision)', data: precisionPts, borderColor: LC.accent, borderWidth: 2, pointRadius: 0 },
            { label: 'θ = 5 μrad (Standard)', data: standardPts, borderColor: LC.orange, borderWidth: 2, pointRadius: 0 },
            { label: curLabel, data: curPoint, borderColor: '#ffffff', backgroundColor: '#ffffff', pointRadius: 7, pointStyle: 'crossRot' as const, pointBorderWidth: 2, showLine: false },
          ],
        },
        options: {
          responsive: true,
          scales: {
            x: { type: 'logarithmic', title: { display: true, text: 'Beam Diameter (mm)', color: LC.text, font: chartFont }, ticks: { color: LC.textDim, font: chartFont }, grid: { color: LC.border }, min: 5, max: 100 },
            y: { type: 'logarithmic', title: { display: true, text: 'εₙ (μm·rad)', color: LC.text, font: chartFont }, ticks: { color: LC.textDim, font: chartFont }, grid: { color: LC.border }, min: 1e-5, max: 100 },
          },
          plugins: {
            title: { display: true, text: titleText, color: LC.text, font: { ...chartFont, size: 13, weight: 600 as const } },
            legend: { labels: { color: LC.textDim, font: chartFont, boxWidth: 20 } },
            annotation: { annotations: emittanceAnnotations },
          },
        },
      });
      emittanceChartCanvas = pbEmittanceCanvas;
    }
  });

  // ── Emittance feasibility heatmap ───────────────────
  function emittanceToColor(epsN_umrad: number): [number, number, number] {
    // Black: below physics floor (<0.05)
    if (epsN_umrad < 0.05) return [10, 12, 18];
    // Yellow zone: physics floor to SOTA (0.05–0.2)
    if (epsN_umrad < 0.2) {
      const t = (epsN_umrad - 0.05) / (0.2 - 0.05);
      return lerp3([40, 35, 0], [251, 191, 36], t); // dark yellow → bright yellow
    }
    // Green zone: near-future achievable (0.2–1.0)
    if (epsN_umrad < 1.0) {
      const t = (epsN_umrad - 0.2) / (1.0 - 0.2);
      return lerp3([251, 191, 36], [74, 222, 128], t); // yellow → green
    }
    // Blue zone: very achievable (≥1.0)
    const t = Math.min(1, (Math.log10(epsN_umrad) - 0) / 2); // 1 → 100 mapped 0→1
    return lerp3([74, 222, 128], [96, 165, 250], t); // green → blue
  }

  $effect(() => {
    if (!pbEmittanceHeatCanvas || activeSubTab !== 'particle') return;
    const ctx = pbEmittanceHeatCanvas.getContext('2d')!;

    const W = 620, H = 420;
    pbEmittanceHeatCanvas.width = W;
    pbEmittanceHeatCanvas.height = H;

    const M = { top: 32, right: 85, bottom: 48, left: 68 };
    const pX = M.left, pY = M.top;
    const pW = W - M.left - M.right;
    const pH = H - M.top - M.bottom;

    const theta = pbDivergence * 1e-6; // current divergence in rad
    const curDiam = pbDiameter;
    const curEnergy = pbEnergy;

    // X: beam diameter 0.1mm → 200mm (log)
    // Y: particle energy 10 MeV → 100,000 MeV (log)
    const logDMin = Math.log10(5), logDMax = Math.log10(200);
    const logEMin = Math.log10(10), logEMax = Math.log10(100000);

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
      // Y axis: energy top=high, bottom=low
      const eMeV = Math.pow(10, logEMax - tY * (logEMax - logEMin));
      const gamma = 1 + eMeV / PROTON_REST_MASS_MEV;
      const beta = Math.sqrt(1 - 1 / (gamma * gamma));
      const bg = beta * gamma;
      for (let col = 0; col < gridW; col++) {
        const tX = col / (gridW - 1);
        const diam_mm = Math.pow(10, logDMin + tX * (logDMax - logDMin));
        const r0 = diam_mm / 2 / 1000; // mm → m
        const epsN = bg * r0 * theta * 1e6; // μm·rad
        const [r, g, b] = emittanceToColor(epsN);
        const idx = (row * gridW + col) * 4;
        px[idx] = r; px[idx + 1] = g; px[idx + 2] = b; px[idx + 3] = 255;
      }
    }
    tmpCtx.putImageData(imgData, 0, 0);
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(tmp, pX, pY, pW, pH);

    // ── Crosshair at current operating point ──────────
    const xCH = pX + ((Math.log10(Math.max(curDiam, 0.1)) - logDMin) / (logDMax - logDMin)) * pW;
    const yCH = pY + (1 - (Math.log10(Math.max(curEnergy, 10)) - logEMin) / (logEMax - logEMin)) * pH;

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

    // Label at crosshair
    const curBg = pbBetaGamma;
    const curEpsN = curBg * (curDiam / 2 / 1000) * theta * 1e6;
    const epsLabel = curEpsN < 0.001 ? curEpsN.toExponential(1) + ' μm·rad' : curEpsN.toFixed(3) + ' μm·rad';
    ctx.font = 'bold 11px JetBrains Mono, monospace';
    const onRight = xCH < pX + pW / 2;
    ctx.textAlign = onRight ? 'left' : 'right';
    ctx.textBaseline = 'bottom';
    const lx = xCH + (onRight ? 10 : -10);
    const tm = ctx.measureText(epsLabel);
    const boxX = onRight ? lx - 3 : lx - tm.width - 3;
    ctx.fillStyle = '#000000cc';
    ctx.fillRect(boxX, yCH - 24, tm.width + 6, 17);
    ctx.fillStyle = '#ffffff';
    ctx.fillText(epsLabel, lx, yCH - 9);

    // ── Axes ──────────────────────────────────────────
    ctx.strokeStyle = LC.border;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(pX, pY); ctx.lineTo(pX, pY + pH); ctx.lineTo(pX + pW, pY + pH);
    ctx.stroke();

    // X ticks (Diameter)
    ctx.fillStyle = LC.textDim;
    ctx.font = '10px JetBrains Mono, monospace';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    const dTicks: [number, string][] = [
      [5, '5'], [10, '10'], [20, '20'],
      [50, '50'], [100, '100'], [200, '200'],
    ];
    for (const [d, label] of dTicks) {
      const x = pX + ((Math.log10(d) - logDMin) / (logDMax - logDMin)) * pW;
      ctx.fillStyle = LC.textDim;
      ctx.fillText(label, x, pY + pH + 5);
      ctx.beginPath(); ctx.moveTo(x, pY + pH); ctx.lineTo(x, pY + pH + 3);
      ctx.strokeStyle = LC.textDim; ctx.stroke();
    }
    ctx.font = '11px JetBrains Mono, monospace';
    ctx.fillText('Beam Diameter (mm)', pX + pW / 2, pY + pH + 22);

    // Y ticks (Energy)
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    ctx.font = '10px JetBrains Mono, monospace';
    const eTicks: [number, string][] = [
      [10, '10'], [100, '100'], [1000, '1 GeV'],
      [10000, '10 GeV'], [100000, '100 GeV'],
    ];
    for (const [e, label] of eTicks) {
      const y = pY + (1 - (Math.log10(e) - logEMin) / (logEMax - logEMin)) * pH;
      ctx.fillStyle = LC.textDim;
      ctx.fillText(label, pX - 6, y);
      ctx.beginPath(); ctx.moveTo(pX - 3, y); ctx.lineTo(pX, y);
      ctx.strokeStyle = LC.textDim; ctx.stroke();
    }
    ctx.save();
    ctx.translate(14, pY + pH / 2);
    ctx.rotate(-Math.PI / 2);
    ctx.textAlign = 'center';
    ctx.font = '11px JetBrains Mono, monospace';
    ctx.fillStyle = LC.textDim;
    ctx.fillText('Particle Energy (MeV)', 0, 0);
    ctx.restore();

    // Title
    ctx.font = 'bold 12px JetBrains Mono, monospace';
    ctx.fillStyle = LC.text;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillText(`Emittance Feasibility (θ = ${formatDivergence(pbDivergence)})`, pX + pW / 2, 6);

    // ── Legend ────────────────────────────────────────
    const legX = pX + pW + 10, legY = pY + 10, legW = 14, legH = pH - 20;
    const legSteps = 80;
    for (let i = 0; i < legSteps; i++) {
      const t = i / (legSteps - 1);
      // Map t=0 (top) → high εₙ, t=1 (bottom) → low εₙ
      const logEps = 2 - t * (2 - (-2)); // log10: 100 → 0.01
      const epsVal = Math.pow(10, logEps);
      const [r, g, b] = emittanceToColor(epsVal);
      ctx.fillStyle = `rgb(${r},${g},${b})`;
      ctx.fillRect(legX, legY + t * legH, legW, legH / legSteps + 1);
    }
    ctx.strokeStyle = LC.border;
    ctx.lineWidth = 1;
    ctx.strokeRect(legX, legY, legW, legH);

    // Legend labels
    ctx.font = '9px JetBrains Mono, monospace';
    ctx.fillStyle = LC.textDim;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    const legLabels: [number, string][] = [
      [100, '100'], [10, '10'], [1, '1.0'], [0.2, '0.2'], [0.05, '0.05'],
    ];
    for (const [val, label] of legLabels) {
      const t = (2 - Math.log10(val)) / 4; // maps 100→0, 0.01→1
      const y = legY + t * legH;
      ctx.fillText(label, legX + legW + 3, y);
    }
    ctx.fillText('μm·rad', legX + legW + 3, legY + legH + 10);
  });

  // ══════════════════════════════════════════════════════
  // ── Accelerator Design Sub-Tab ──────────────────────
  // ══════════════════════════════════════════════════════

  let accLength = $state(10);         // m — accelerator length
  let accPowerIn = $state(10);        // MW — electrical power input
  let accExitDiam = $state(0.4);      // cm — beam diameter at exit
  let accGradient = $state(20);       // MV/m — accelerating gradient
  let accTargetSpotR = $state(0.25);  // cm — target spot radius

  // Fixed constants
  const ACC_EFFICIENCY = 0.30;        // 30% wall-plug to beam
  const ACC_DIVERGENCE = 5e-7;        // 0.5 μrad — fixed beam divergence
  const ACC_DIVERGENCE_URAD = ACC_DIVERGENCE * 1e6;

  // Derived accelerator values
  let accParticleKE = $derived(accGradient * accLength); // MeV
  let accGamma = $derived(1 + accParticleKE / PROTON_REST_MASS_MEV);
  let accBeta = $derived(Math.sqrt(1 - 1 / (accGamma * accGamma)));
  let accBetaGamma = $derived(accBeta * accGamma);
  let accBeamPower = $derived(ACC_EFFICIENCY * accPowerIn); // MW
  let accR0 = $derived(accExitDiam / 2 / 100); // cm → m (radius)
  // Emittance derived from fixed divergence: ε = θ · r₀, εₙ = βγ · ε
  let accGeomEmittance = $derived(ACC_DIVERGENCE * accR0); // m·rad
  let accNormEmittance = $derived(accBetaGamma * accGeomEmittance * 1e6); // μm·rad
  let accCurrent = $derived((accBeamPower * 1e6) / (accParticleKE * 1e6)); // A
  let accPerveance = $derived(
    (2 * accCurrent) / (ALFVEN_CURRENT_PROTON * Math.pow(accBetaGamma, 3))
  );

  // Target requirement: 33 kJ absorbed in 0.5 s
  let accTargetR = $derived(accTargetSpotR / 100); // cm → m
  const ACC_TARGET_ENERGY = 33000;    // 33 kJ in joules
  const ACC_TARGET_TIME = 0.5;        // seconds
  const ACC_TARGET_POWER = ACC_TARGET_ENERGY / ACC_TARGET_TIME; // 66 kW

  function formatCm(cm: number): string {
    if (cm >= 1) return cm.toFixed(1) + ' cm';
    return (cm * 10).toFixed(1) + ' mm';
  }

  // Spot radius at range for accelerator tab
  function accSpotRadius(z_m: number): number {
    return pbSpotRadiusAt(z_m, ACC_DIVERGENCE, accPerveance, accR0);
  }

  // Power absorbed by target at range (W)
  function accAbsorbedOnTarget(z_m: number): number {
    const spotR = accSpotRadius(z_m);
    const tR = accTargetR;
    const fraction = Math.min(1, (tR / spotR) ** 2);
    return PB_DEPOSITION * (accBeamPower * 1e6) * fraction;
  }

  // Max effective range via binary search
  let accMaxRange = $derived.by(() => {
    // First check if the beam can even meet the requirement at point-blank
    if (accAbsorbedOnTarget(0.01) * ACC_TARGET_TIME < ACC_TARGET_ENERGY) return 0;
    let lo = 0.01, hi = 1e7; // 0.01m to 10,000 km
    for (let i = 0; i < 80; i++) {
      const mid = Math.sqrt(lo * hi); // geometric midpoint for log search
      if (accAbsorbedOnTarget(mid) * ACC_TARGET_TIME >= ACC_TARGET_ENERGY) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo; // meters
  });

  // ── Particle beam charts ──────────────────────────────
  let pbChartCanvas = $state<HTMLCanvasElement>();
  let pbHeatmapCanvas = $state<HTMLCanvasElement>();
  let pb3dDiv = $state<HTMLDivElement>();
  let pbEmittanceCanvas = $state<HTMLCanvasElement>();
  let pbEmittanceHeatCanvas = $state<HTMLCanvasElement>();
  let accChartCanvas = $state<HTMLCanvasElement>();
  let pbDepthChart: Chart | undefined;
  let pbDepthChartCanvas: HTMLCanvasElement | undefined;
  let accChart: Chart | undefined;
  let accChartBound: HTMLCanvasElement | undefined;

  // Time vs depth chart
  $effect(() => {
    if (!pbChartCanvas || activeSubTab !== 'particle') {
      if (pbDepthChart) { pbDepthChart.destroy(); pbDepthChart = undefined; pbDepthChartCanvas = undefined; }
      return;
    }
    const apd = pbAbsorbedPowerDensity;
    const epv = energyPerVolume;
    const mp = maxPlate;
    const matName = targetMaterial.name;
    const numPoints = 200;
    const maxTime = 30;
    const times: number[] = [];
    const depths: number[] = [];
    for (let i = 0; i <= numPoints; i++) {
      const t = (i / numPoints) * maxTime;
      times.push(t);
      depths.push(Math.min(calcPen(apd, t, epv), mp));
    }

    const labels = times.map(t => t.toFixed(1));
    const depthsMm = depths.map(d => d * 1000);
    const plateLine = times.map(() => mp * 1000);
    const yMax = Math.max(mp * 1000, depths[depths.length - 1] * 1000 * 1.1);
    const titleText = `${matName} Penetration vs Exposure Time (Charged Proton Beam)`;
    const plateLabel = `Plate Thickness (${(mp * 1000).toFixed(0)}mm)`;

    if (pbDepthChart && pbDepthChartCanvas === pbChartCanvas) {
      pbDepthChart.data.labels = labels;
      pbDepthChart.data.datasets[0].data = depthsMm;
      pbDepthChart.data.datasets[1].data = plateLine;
      pbDepthChart.data.datasets[1].label = plateLabel;
      pbDepthChart.options.scales!.y!.max = yMax;
      (pbDepthChart.options.plugins!.title as any).text = titleText;
      pbDepthChart.options.scales!.x!.ticks!.callback = (_, i) => {
        const t = times[i as number];
        return t !== undefined && t % 5 === 0 ? t + 's' : '';
      };
      pbDepthChart.update('none');
    } else {
      pbDepthChart?.destroy();
      pbDepthChart = new Chart(pbChartCanvas, {
        type: 'line',
        data: {
          labels,
          datasets: [
            {
              label: 'Penetration Depth',
              data: depthsMm,
              borderColor: LC.green,
              backgroundColor: LC.green + '22',
              fill: true,
              tension: 0.3,
              pointRadius: 0,
            },
            {
              label: plateLabel,
              data: plateLine,
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
              max: yMax,
            },
          },
          plugins: {
            title: {
              display: true,
              text: titleText,
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
      pbDepthChartCanvas = pbChartCanvas;
    }
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
    const curRange = pbRange;
    const curPower = pbPower;
    const r0 = pbR0m;
    const epv = energyPerVolume;

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

    // Penetration below 1mm/s = blacked out (ineffective)
    const PB_BLACKOUT_MM = 1.0;

    for (let row = 0; row < gridH; row++) {
      const tY = row / (gridH - 1);
      const pMW = Math.pow(10, logPMax - tY * (logPMax - logPMin));
      for (let col = 0; col < gridW; col++) {
        const tX = col / (gridW - 1);
        const rKm = Math.pow(10, logRMin + tX * (logRMax - logRMin));
        const pen = calcPenPBStandalone(pMW, rKm, div, eng, r0, epv);
        const idx = (row * gridW + col) * 4;
        if (pen * 1000 < PB_BLACKOUT_MM) {
          px[idx] = 10; px[idx+1] = 12; px[idx+2] = 18; px[idx+3] = 255;
        } else {
          const [r, g, b] = penToColor(pen);
          px[idx] = r; px[idx+1] = g; px[idx+2] = b; px[idx+3] = 255;
        }
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

    const curPen = calcPenPBStandalone(curPower, curRange, div, eng, r0, epv);
    const penLabel = curPen * 1000 < PB_BLACKOUT_MM ? 'INEFFECTIVE' : formatDepth(curPen);
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
    const titleDetail = `Charged Proton, ${formatDivergence(div)}, ${formatParticleEnergy(eng)}`;
    ctx.fillStyle = LC.text;
    ctx.font = 'bold 12px JetBrains Mono, monospace';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';
    ctx.fillText(`Range vs Power \u2014 1s Impulse (${titleDetail})`, W / 2, pY - 8);

    // Color legend bar — 1mm to 300mm only, small black key below
    const legX = pX + pW + 14, legW = 12;
    const logDMin = 0, logDMax = Math.log10(300); // 1mm → 300mm

    for (let i = 0; i < pH; i++) {
      const t = i / pH;
      const mm = Math.pow(10, logDMax - t * (logDMax - logDMin));
      const [r, g, b] = penToColor(mm / 1000);
      ctx.fillStyle = `rgb(${r},${g},${b})`;
      ctx.fillRect(legX, pY + i, legW, 1.5);
    }
    ctx.strokeStyle = LC.border;
    ctx.strokeRect(legX, pY, legW, pH);

    // Black key below the gradient
    const keyY = pY + pH + 6;
    ctx.fillStyle = 'rgb(10, 12, 18)';
    ctx.fillRect(legX, keyY, legW, legW);
    ctx.strokeStyle = LC.border;
    ctx.strokeRect(legX, keyY, legW, legW);
    ctx.fillStyle = LC.textDim;
    ctx.font = '9px JetBrains Mono, monospace';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText('Ineffective', legX + legW + 3, keyY + legW / 2);

    // Legend tick labels
    for (const { mm, text } of [
      { mm: 300, text: '30cm' }, { mm: 50, text: '5cm' },
      { mm: 1, text: '1mm' },
    ]) {
      const y = pY + ((logDMax - Math.log10(mm)) / (logDMax - logDMin)) * pH;
      ctx.fillText(text, legX + legW + 3, y);
    }

    return () => {};
  });

  // ── 3D Surface Plot: Range × Time → Depth (color = time) ──
  $effect(() => {
    if (!pb3dDiv || activeSubTab !== 'particle') return;

    const div = pbDivergence;
    const eng = pbEnergy;
    const pwr = pbPower;
    const r0 = pbR0m;
    const epv = energyPerVolume;
    const mp = maxPlate;
    const mpMM = mp * 1000;

    const NR = 60, NT = 60;
    // Range: 1m (0.001 km) → 100 km, log-spaced
    const logRMin = -3, logRMax = 2;
    // Time: 0.01s → 30s, log-spaced
    const logTMin = Math.log10(0.01), logTMax = Math.log10(30);

    const rangeVals: number[] = [];
    const timeVals: number[] = [];
    for (let i = 0; i < NR; i++) {
      rangeVals.push(Math.pow(10, logRMin + (i / (NR - 1)) * (logRMax - logRMin)));
    }
    for (let i = 0; i < NT; i++) {
      timeVals.push(Math.pow(10, logTMin + (i / (NT - 1)) * (logTMax - logTMin)));
    }

    // Z = penetration depth (mm, capped at plate thickness)
    // Color = time value; -1 sentinel for ineffective (< 1mm)
    const PB_BLACKOUT_MM = 1.0;
    const zData: number[][] = [];
    const colorData: number[][] = [];
    const hoverText: string[][] = [];

    // Precompute penetration rate per second and spot diameter at each range
    const ratePerSec: number[] = rangeVals.map(rKm =>
      calcPenPBStandalone(pwr, rKm, div, eng, r0, epv)
    );
    const spotDiamAtRange: number[] = rangeVals.map(rKm =>
      2 * pbSpotRadiusAtStandalone(rKm, div, eng, pwr, r0)
    );

    for (let ti = 0; ti < NT; ti++) {
      const zRow: number[] = [];
      const cRow: number[] = [];
      const hRow: string[] = [];
      const t = timeVals[ti];
      for (let ri = 0; ri < NR; ri++) {
        const rKm = rangeVals[ri];
        const depthM = Math.min(ratePerSec[ri] * t, mp);
        const depthMM = depthM * 1000;

        zRow.push(depthMM);
        cRow.push(depthMM < PB_BLACKOUT_MM ? -1 : t);

        const rangeLabel = rKm < 1 ? (rKm * 1000).toFixed(0) + ' m' : rKm.toFixed(rKm < 10 ? 1 : 0) + ' km';
        const timeLabel = t < 1 ? (t * 1000).toFixed(0) + ' ms' : t.toFixed(1) + ' s';
        const depthLabel = depthMM < PB_BLACKOUT_MM ? 'negligible' : depthMM.toFixed(1) + ' mm';
        const sd = spotDiamAtRange[ri];
        const spotLabel = sd >= 1 ? sd.toFixed(1) + ' m' : sd >= 0.01 ? (sd * 100).toFixed(1) + ' cm' : (sd * 1000).toFixed(2) + ' mm';
        hRow.push(`Range: ${rangeLabel}<br>Time: ${timeLabel}<br>Depth: ${depthLabel}<br>Beam ⌀: ${spotLabel}`);
      }
      zData.push(zRow);
      colorData.push(cRow);
      hoverText.push(hRow);
    }

    // Colorscale: -1=black(ineffective), 0→30 = white→blue
    // Map onto cmin=-1, cmax=30; -1/31→0 = black, then 0→30 = white→blue
    const colorscale: [number, string][] = [
      [0,    '#0a0c12'],   // -1: ineffective / black
      [0.02, '#0a0c12'],   // still black near sentinel
      [0.035,'#e2e8f0'],   // ~0s: white
      [0.20, '#a7f3d0'],   // ~5s: light green
      [0.50, '#68d391'],   // ~14s: green
      [0.75, '#4facdb'],   // ~22s: teal-blue
      [1.0,  '#2b6cb0'],   // 30s: solid blue
    ];

    const titleDetail = `Charged Proton, ${formatPowerCompact(pwr)}, ${formatDivergence(div)}, ${formatParticleEnergy(eng)}`;

    const trace: Partial<Plotly.PlotData> & { type: string } = {
      type: 'surface',
      x: rangeVals,
      y: timeVals,
      z: zData,
      surfacecolor: colorData,
      colorscale,
      cmin: -1,
      cmax: 30,
      colorbar: {
        title: { text: 'Time (s)', font: { color: '#e2e8f0', size: 11, family: 'JetBrains Mono, monospace' } },
        tickvals: [0, 5, 10, 15, 20, 25, 30],
        ticktext: ['0s', '5s', '10s', '15s', '20s', '25s', '30s'],
        tickfont: { color: '#8492a6', size: 10, family: 'JetBrains Mono, monospace' },
        len: 0.75,
        thickness: 15,
        outlinecolor: '#2a3142',
        bgcolor: '#0e1117',
      },
      hoverinfo: 'text',
      text: hoverText,
      contours: {
        z: { show: true, usecolormap: false, color: '#2a3142', width: 1 },
      },
    } as any;

    const layout: Partial<Plotly.Layout> = {
      title: {
        text: `Range × Time → Penetration (${titleDetail})`,
        font: { color: '#e2e8f0', size: 13, family: 'JetBrains Mono, monospace' },
      },
      paper_bgcolor: '#0e1117',
      scene: {
        xaxis: {
          title: { text: 'Range', font: { color: '#8492a6', size: 11, family: 'JetBrains Mono, monospace' } },
          type: 'log',
          tickvals: [0.001, 0.01, 0.1, 1, 10, 100],
          ticktext: ['1m', '10m', '100m', '1km', '10km', '100km'],
          tickfont: { color: '#8492a6', size: 9, family: 'JetBrains Mono, monospace' },
          gridcolor: '#2a3142',
          zerolinecolor: '#2a3142',
          backgroundcolor: '#0e1117',
          showbackground: true,
        },
        yaxis: {
          title: { text: 'Time (s)', font: { color: '#8492a6', size: 11, family: 'JetBrains Mono, monospace' } },
          type: 'log',
          tickvals: [0.01, 0.1, 1, 5, 10, 30],
          ticktext: ['10ms', '100ms', '1s', '5s', '10s', '30s'],
          tickfont: { color: '#8492a6', size: 9, family: 'JetBrains Mono, monospace' },
          gridcolor: '#2a3142',
          zerolinecolor: '#2a3142',
          backgroundcolor: '#0e1117',
          showbackground: true,
        },
        zaxis: {
          title: { text: 'Depth (mm)', font: { color: '#8492a6', size: 11, family: 'JetBrains Mono, monospace' } },
          range: [0, mpMM],
          tickfont: { color: '#8492a6', size: 9, family: 'JetBrains Mono, monospace' },
          gridcolor: '#2a3142',
          zerolinecolor: '#2a3142',
          backgroundcolor: '#0e1117',
          showbackground: true,
        },
        bgcolor: '#0e1117',
        camera: { eye: { x: 1.5, y: -1.8, z: 0.9 } },
      },
      margin: { t: 40, b: 10, l: 10, r: 10 },
      font: { color: '#e2e8f0' },
    };

    const config: Partial<Plotly.Config> = {
      responsive: true,
      displayModeBar: true,
      modeBarButtonsToRemove: ['toImage', 'sendDataToCloud'] as any[],
      displaylogo: false,
    };

    Plotly.react(pb3dDiv, [trace as any], layout, config);

    return () => {
      Plotly.purge(pb3dDiv!);
    };
  });

  // ── Accelerator: Spot Diameter vs Range chart ───────────
  $effect(() => {
    if (!accChartCanvas || activeSubTab !== 'particle' || particleSubTab !== 'accelerator') {
      if (accChart) { accChart.destroy(); accChart = undefined; accChartBound = undefined; }
      return;
    }

    // Touch reactive deps
    const _deps = [accLength, accPowerIn, accExitDiam, accGradient, accTargetSpotR];

    const maxR = accMaxRange;
    const tR = accTargetR;
    const tD_mm = tR * 2 * 1000;
    const numPoints = 300;
    const plotMax = Math.max(maxR * 3, 100);
    const logMin = Math.log10(0.1);
    const logMax = Math.log10(plotMax);

    const points: { x: number; y: number }[] = [];
    const lossData: number[] = [];

    for (let i = 0; i <= numPoints; i++) {
      const t = i / numPoints;
      const z = Math.pow(10, logMin + t * (logMax - logMin));
      const spotR = accSpotRadius(z);
      const spotD_mm = spotR * 2 * 1000;
      const fraction = Math.min(1, (tR / spotR) ** 2);
      const loss = (1 - fraction) * 100;
      points.push({ x: z, y: spotD_mm });
      lossData.push(loss);
    }

    const refLine = [
      { x: points[0].x, y: tD_mm },
      { x: points[points.length - 1].x, y: tD_mm },
    ];
    const maxRangeLine = maxR > 0 ? [
      { x: maxR, y: points[0].y },
      { x: maxR, y: Math.max(points[points.length - 1].y, 1000) },
    ] : [];

    const titleText = maxR > 0
      ? `Spot Diameter vs Range — Max Effective: ${formatRangeLabel(maxR / 1000)}`
      : 'Spot Diameter vs Range — Insufficient power at any range';
    const targetLabel = `Target (${formatCm(accTargetSpotR * 2)} ⌀)`;
    const maxRangeLabel = `Max Range (${formatRangeLabel(maxR / 1000)})`;

    // Variable dataset count (max range line is conditional) — rebuild datasets each time
    const datasets: any[] = [
      { label: 'Spot Diameter', data: points, showLine: true, borderColor: LC.accent, backgroundColor: LC.accent + '22', pointRadius: 0, pointHitRadius: 8, borderWidth: 2, fill: false },
      { label: targetLabel, data: refLine, showLine: true, borderColor: LC.red + '88', borderDash: [6, 4], pointRadius: 0, pointHitRadius: 0, borderWidth: 1, fill: false },
      ...(maxR > 0 ? [{ label: maxRangeLabel, data: maxRangeLine, showLine: true, borderColor: LC.green + 'aa', borderDash: [4, 4], pointRadius: 0, pointHitRadius: 0, borderWidth: 1, fill: false }] : []),
    ];

    const tooltipCallbacks = {
      title: (items: any[]) => {
        const z = (items[0].raw as { x: number }).x;
        return z >= 1000 ? (z / 1000).toFixed(2) + ' km' : z.toFixed(1) + ' m';
      },
      label: (item: any) => {
        const idx = item.dataIndex;
        const spotMM = (item.raw as { y: number }).y;
        const loss = lossData[idx];
        const spotLabel = spotMM >= 1000 ? (spotMM / 1000).toFixed(2) + ' m' : spotMM >= 10 ? spotMM.toFixed(1) + ' mm' : spotMM.toFixed(2) + ' mm';
        return [` Spot: ${spotLabel}`, ` Power loss: ${loss.toFixed(1)}%`];
      },
    };

    if (accChart && accChartBound === accChartCanvas) {
      accChart.data.datasets = datasets;
      (accChart.options.plugins!.title as any).text = titleText;
      (accChart.options.plugins!.tooltip as any).callbacks = tooltipCallbacks;
      accChart.update('none');
    } else {
      accChart?.destroy();
      accChart = new Chart(accChartCanvas, {
        type: 'scatter',
        data: { datasets },
        options: {
          responsive: true,
          maintainAspectRatio: true,
          aspectRatio: 2,
          scales: {
            x: {
              type: 'logarithmic',
              title: { display: true, text: 'Range', color: LC.textDim, font: chartFont },
              ticks: { color: LC.textDim, font: { size: 10 }, callback: (val) => { const v = Number(val); return v >= 1000 ? (v / 1000).toFixed(0) + ' km' : v.toFixed(0) + ' m'; } },
              grid: { color: LC.border },
            },
            y: {
              type: 'logarithmic',
              title: { display: true, text: 'Spot Diameter (mm)', color: LC.textDim, font: chartFont },
              ticks: { color: LC.textDim, font: { size: 10 }, callback: (val) => { const v = Number(val); return v >= 1000 ? (v / 1000).toFixed(0) + ' m' : v >= 10 ? v.toFixed(0) + ' mm' : v.toFixed(1) + ' mm'; } },
              grid: { color: LC.border },
            },
          },
          plugins: {
            title: { display: true, text: titleText, color: LC.text, font: { ...chartFont, size: 13, weight: 600 as const } },
            legend: { labels: { color: LC.textDim, font: { size: 10 }, padding: 8 } },
            tooltip: { backgroundColor: LC.surface, borderColor: LC.border, borderWidth: 1, titleColor: LC.text, bodyColor: LC.textDim, filter: (item) => item.datasetIndex === 0, callbacks: tooltipCallbacks },
          },
        },
      });
      accChartBound = accChartCanvas;
    }
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
      <details class="equations-section">
        <summary><h3>Governing Equation</h3></summary>
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
      </details>

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
            <select bind:value={projMaterialIndex}>
              {#each projectileMaterials as mat, i}
                <option value={i}>{mat.name} ({mat.density_kgm3.toLocaleString()} kg/m³)</option>
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
      <details class="equations-section">
        <summary><h3>Governing Equations</h3></summary>
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
      </details>

      <!-- ── Calculator ────────────────────────────────── -->
      <div class="calc-panel">
        <div class="calc-grid">

          <SliderInput label="Aperture (cm)" bind:value={laserAperture} min={5} max={200} step={1} />
          <SliderInput label="Wavelength (nm)" bind:value={laserWavelength} min={200} max={10600} step={1} />
          <SliderInput label="Power ({formatPowerCompact(laserPower)})" bind:value={laserPower} min={0.1} max={100000} step={0.1} log />
          <SliderInput label="Range (km)" bind:value={laserRange} min={1} max={1000} step={1} inputMax={10000} />

          <div class="field-group">
            <label class="field-label">Target Material</label>
            <select bind:value={targetMaterialIndex}>
              {#each targetMaterials as mat, i}
                <option value={i}>{mat.name}</option>
              {/each}
            </select>
          </div>
          <SliderInput label="Plate Thickness ({plateThickness} cm)" bind:value={plateThickness} min={1} max={200} step={1} />

        </div>

        <!-- ── Computed values ─────────────────────────── -->
        <details class="results" open>
          <summary class="results-toggle">Computed Values</summary>
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
          <div class="result-row primary">
            <span class="result-label">Penetration rate</span>
            <span class="result-value">{formatPenRate(laserPenRate)}</span>
          </div>
        </details>
      </div>

      <!-- ── Visualizations (3-column grid) ─────────────── -->
      <div class="viz-grid">
        <details class="viz-toggle" open draggable="true" style="order: {laserVizOrder.indexOf(0)}"
          class:viz-drag-over={dragOverId?.group === 'laser' && dragOverId?.id === 0}
          ondragstart={(e) => vizDragStart(e, 'laser', 0)} ondragend={vizDragEnd}
          ondragover={(e) => vizDragOver(e, 'laser', 0)} ondragleave={vizDragLeave}
          ondrop={(e) => vizDrop(e, 'laser', 0)}>
          <summary><span class="drag-handle">⋮⋮</span> Penetration Bar</summary>
          <div class="calc-panel">
            <h3 class="bar-title">{targetMaterial.name} Plate Penetration (up to {plateThickness} cm)</h3>
            <p class="bar-note">Absorption model is steel-specific; penetration uses selected material's thermal properties.</p>

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

              <div class="pen-scale">
                <span>0</span>
                <span>{Math.round(plateThickness / 3)} cm</span>
                <span>{Math.round(plateThickness * 2 / 3)} cm</span>
                <span>{plateThickness} cm</span>
              </div>
            </div>

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
        </details>

        <details class="viz-toggle" open draggable="true" style="order: {laserVizOrder.indexOf(1)}"
          class:viz-drag-over={dragOverId?.group === 'laser' && dragOverId?.id === 1}
          ondragstart={(e) => vizDragStart(e, 'laser', 1)} ondragend={vizDragEnd}
          ondragover={(e) => vizDragOver(e, 'laser', 1)} ondragleave={vizDragLeave}
          ondrop={(e) => vizDrop(e, 'laser', 1)}>
          <summary><span class="drag-handle">⋮⋮</span> Penetration vs Time</summary>
          <div class="chart-section">
            <canvas bind:this={laserCanvas}></canvas>
          </div>
        </details>

        <details class="viz-toggle" open draggable="true" style="order: {laserVizOrder.indexOf(2)}"
          class:viz-drag-over={dragOverId?.group === 'laser' && dragOverId?.id === 2}
          ondragstart={(e) => vizDragStart(e, 'laser', 2)} ondragend={vizDragEnd}
          ondragover={(e) => vizDragOver(e, 'laser', 2)} ondragleave={vizDragLeave}
          ondrop={(e) => vizDrop(e, 'laser', 2)}>
          <summary><span class="drag-handle">⋮⋮</span> Range vs Power</summary>
          <div class="chart-section heatmap-wrap">
            <canvas bind:this={heatmapCanvas}></canvas>
          </div>
        </details>
      </div>

    {/if}

    {#if activeSubTab === 'particle'}

      <nav class="particle-sub-tabs">
        <button class="psub-btn" class:active={particleSubTab === 'combat'} onclick={() => particleSubTab = 'combat'}>Combat Analysis</button>
        <button class="psub-btn" class:active={particleSubTab === 'accelerator'} onclick={() => particleSubTab = 'accelerator'}>Accelerator Design</button>
      </nav>

      {#if particleSubTab === 'combat'}

      <!-- ── Governing Equations ───────────────────────── -->
      <details class="equations-section">
        <summary><h3>Governing Equations</h3></summary>
        <div class="equation-block">
          <div class="equation">
            <span class="eq-var">KE</span> = <span class="eq-var">G</span> &middot; <span class="eq-var">L</span>
          </div>
          <div class="eq-label">Particle energy from accelerating gradient &times; length</div>
          <div class="eq-desc">
            <span class="eq-var-sm">G</span> = gradient (MV/m, auto-optimized) &middot;
            <span class="eq-var-sm">L</span> = accelerator length (m)
          </div>
        </div>
        <div class="equation-block" style="margin-top: 0.75rem;">
          <div class="equation">
            <span class="eq-var">d<sub>spot</sub></span> = 2(<span class="eq-var">r<sub>0</sub></span> + <span class="eq-var">&theta;</span> &middot; <span class="eq-var">R</span> + <span class="eq-var">K</span> &middot; <span class="eq-var">R</span><sup>2</sup> / 2<span class="eq-var">r<sub>0</sub></span>)
          </div>
          <div class="eq-label">Spot diameter at range &mdash; geometric + space-charge expansion</div>
          <div class="eq-desc">
            <span class="eq-var-sm">r<sub>0</sub></span> = source beam radius ({pbDiameter / 2} mm, at accelerator exit) &middot;
            <span class="eq-var-sm">&theta;</span> = half-angle divergence &middot;
            <span class="eq-var-sm">R</span> = range to target &middot;
            <span class="eq-var-sm">K</span> = generalized perveance
          </div>
        </div>
        <div class="equation-block" style="margin-top: 0.75rem;">
          <div class="equation">
            <span class="eq-var">K</span> = 2<span class="eq-var">I</span> / (<span class="eq-var">I<sub>A</sub></span> &middot; (<span class="eq-var">&beta;&gamma;</span>)<sup>3</sup>)
          </div>
          <div class="eq-label">Generalized perveance &mdash; space-charge strength</div>
          <div class="eq-desc">
            <span class="eq-var-sm">I</span> = beam current (P/KE) &middot;
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
        <div class="equation-block" style="margin-top: 0.75rem;">
          <div class="equation">
            <span class="eq-var">&epsilon;</span> = <span class="eq-var">r<sub>0</sub></span> &middot; <span class="eq-var">&theta;</span> &nbsp;&nbsp;&rarr;&nbsp;&nbsp;
            <span class="eq-var">&epsilon;<sub>n</sub></span> = <span class="eq-var">&beta;&gamma;</span> &middot; <span class="eq-var">&epsilon;</span>
          </div>
          <div class="eq-label">Geometric &amp; normalized emittance &mdash; beam quality (Liouville invariant)</div>
          <div class="eq-desc">
            <span class="eq-var-sm">r<sub>0</sub></span> = source beam radius at exit (⌀/2) &middot;
            <span class="eq-var-sm">&theta;</span> = half-angle divergence &middot;
            <span class="eq-var-sm">&beta;&gamma;</span> = relativistic momentum factor (from KE) &middot;
            Evaluated at source (not at target) &middot; Must satisfy <span class="eq-var-sm">&epsilon;<sub>n</sub></span> &ge; 0.05 &mu;m&middot;rad (physics floor)
          </div>
        </div>
      </details>

      <!-- ── Calculator ──────────────────────────────────── -->
      <div class="calc-panel">
        <div class="calc-grid">
          <div class="field-group">
            <label class="field-label">Divergence</label>
            <div class="shape-buttons">
              <button class="shape-btn" class:active={pbDivChoice === 'standard'} onclick={() => pbDivChoice = 'standard'}>5 μrad</button>
              <button class="shape-btn" class:active={pbDivChoice === 'precision'} onclick={() => pbDivChoice = 'precision'}>0.5 μrad</button>
            </div>
          </div>
          <SliderInput label="Beam ⌀ ({pbDiameter} mm)" bind:value={pbDiameter} min={5} max={100} step={0.1} log />
          <SliderInput label="Accel. Length ({pbAccelLength} m)" bind:value={pbAccelLength} min={1} max={500} step={1} />
          <SliderInput label="Gradient ({pbGradient.toFixed(1)} MV/m)" bind:value={pbGradient} min={PB_GRADIENT_MIN} max={PB_GRADIENT_MAX} step={0.1} log />
          <SliderInput label="Beam Power ({formatPowerCompact(pbPower)})" bind:value={pbPower} min={0.1} max={100000} step={0.1} log />
          <SliderInput label="Range ({formatRangeLabel(pbRange)})" bind:value={pbRange} min={0.001} max={100} step={0.001} log inputMax={1000} />

          <div class="field-group">
            <label class="field-label">Target Material</label>
            <select bind:value={targetMaterialIndex}>
              {#each targetMaterials as mat, i}
                <option value={i}>{mat.name}</option>
              {/each}
            </select>
          </div>
          <SliderInput label="Plate Thickness ({plateThickness} cm)" bind:value={plateThickness} min={1} max={200} step={1} />
        </div>

        <!-- ── Computed values ─────────────────────────── -->
        <details class="results" open>
          <summary class="results-toggle">Computed Values</summary>
          <div class="result-row">
            <span class="result-label">Gradient (G)</span>
            <span class="result-value">{pbGradient.toFixed(1)} MV/m {pbGradient === pbOptimalGradient ? '' : `(optimal: ${pbOptimalGradient.toFixed(1)})`}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Particle energy (KE = G &times; L)</span>
            <span class="result-value">{formatParticleEnergy(pbEnergy)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Beam current (I = P/KE)</span>
            <span class="result-value">{formatCurrent(pbCurrent)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Perveance (K)</span>
            <span class="result-value">{pbPerveance.toExponential(2)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Beam ⌀ at source (1 cm)</span>
            <span class="result-value">{pbDiameter} mm</span>
          </div>
          <div class="result-row">
            <span class="result-label">Spot ⌀ at {formatRangeLabel(pbRange)}</span>
            <span class="result-value">{formatSpot(pbSpotDiameter)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Power at target ({formatRangeLabel(pbRange)})</span>
            <span class="result-value">{(PB_DEPOSITION * pbPower).toFixed(2)} MW ({(PB_DEPOSITION * 100).toFixed(0)}% deposition)</span>
          </div>
          <div class="result-row">
            <span class="result-label">Absorbed power density</span>
            <span class="result-value">{formatPowerDensity(pbAbsorbedPowerDensity)}</span>
          </div>
          <div class="result-row primary">
            <span class="result-label">Penetration rate</span>
            <span class="result-value">{formatPenRate(pbPenRate)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Emittance εₙ (at source ⌀)</span>
            <span class="result-value">{(pbNormEmittance * 1e6).toFixed(3)} μm·rad</span>
          </div>

          <!-- ── Feasibility Warnings ─────────────────────── -->
          {#if pbFeasibility.length > 0}
            <div class="feasibility-warnings">
              {#each pbFeasibility as check}
                <div class="feasibility-item {check.level}">
                  <span class="feasibility-icon">
                    {#if check.level === 'error'}✕{:else if check.level === 'warning'}⚠{:else}✓{/if}
                  </span>
                  <div class="feasibility-text">
                    <span class="feasibility-label">{check.label}</span>
                    <span class="feasibility-detail">{check.detail}</span>
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </details>
      </div>

      <!-- ── Visualizations (3-column grid) ─────────────── -->
      <div class="viz-grid">
        <details class="viz-toggle" open draggable="true" style="order: {pbVizOrder.indexOf(0)}"
          class:viz-drag-over={dragOverId?.group === 'pb' && dragOverId?.id === 0}
          ondragstart={(e) => vizDragStart(e, 'pb', 0)} ondragend={vizDragEnd}
          ondragover={(e) => vizDragOver(e, 'pb', 0)} ondragleave={vizDragLeave}
          ondrop={(e) => vizDrop(e, 'pb', 0)}>
          <summary><span class="drag-handle">⋮⋮</span> Penetration Bar</summary>
          <div class="calc-panel">
            <h3 class="bar-title">{targetMaterial.name} Plate Penetration (up to {plateThickness} cm)</h3>

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
                <span>{Math.round(plateThickness / 3)} cm</span>
                <span>{Math.round(plateThickness * 2 / 3)} cm</span>
                <span>{plateThickness} cm</span>
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
        </details>

        <details class="viz-toggle" open draggable="true" style="order: {pbVizOrder.indexOf(1)}"
          class:viz-drag-over={dragOverId?.group === 'pb' && dragOverId?.id === 1}
          ondragstart={(e) => vizDragStart(e, 'pb', 1)} ondragend={vizDragEnd}
          ondragover={(e) => vizDragOver(e, 'pb', 1)} ondragleave={vizDragLeave}
          ondrop={(e) => vizDrop(e, 'pb', 1)}>
          <summary><span class="drag-handle">⋮⋮</span> Penetration vs Time</summary>
          <div class="chart-section">
            <canvas bind:this={pbChartCanvas}></canvas>
          </div>
        </details>

        <details class="viz-toggle" open draggable="true" style="order: {pbVizOrder.indexOf(2)}"
          class:viz-drag-over={dragOverId?.group === 'pb' && dragOverId?.id === 2}
          ondragstart={(e) => vizDragStart(e, 'pb', 2)} ondragend={vizDragEnd}
          ondragover={(e) => vizDragOver(e, 'pb', 2)} ondragleave={vizDragLeave}
          ondrop={(e) => vizDrop(e, 'pb', 2)}>
          <summary><span class="drag-handle">⋮⋮</span> Range vs Power</summary>
          <div class="chart-section heatmap-wrap">
            <canvas bind:this={pbHeatmapCanvas}></canvas>
          </div>
        </details>

        <details class="viz-toggle" open draggable="true" style="order: {pbVizOrder.indexOf(3)}"
          class:viz-drag-over={dragOverId?.group === 'pb' && dragOverId?.id === 3}
          ondragstart={(e) => vizDragStart(e, 'pb', 3)} ondragend={vizDragEnd}
          ondragover={(e) => vizDragOver(e, 'pb', 3)} ondragleave={vizDragLeave}
          ondrop={(e) => vizDrop(e, 'pb', 3)}>
          <summary><span class="drag-handle">⋮⋮</span> 3D Surface</summary>
          <div class="chart-section">
            <div bind:this={pb3dDiv} class="plotly-3d-container"></div>
          </div>
        </details>

        <details class="viz-toggle" open draggable="true" style="order: {pbVizOrder.indexOf(4)}"
          class:viz-drag-over={dragOverId?.group === 'pb' && dragOverId?.id === 4}
          ondragstart={(e) => vizDragStart(e, 'pb', 4)} ondragend={vizDragEnd}
          ondragover={(e) => vizDragOver(e, 'pb', 4)} ondragleave={vizDragLeave}
          ondrop={(e) => vizDrop(e, 'pb', 4)}>
          <summary><span class="drag-handle">⋮⋮</span> Emittance Chart</summary>
          <div class="chart-section">
            <canvas bind:this={pbEmittanceCanvas}></canvas>
          </div>
        </details>

        <details class="viz-toggle" open draggable="true" style="order: {pbVizOrder.indexOf(5)}"
          class:viz-drag-over={dragOverId?.group === 'pb' && dragOverId?.id === 5}
          ondragstart={(e) => vizDragStart(e, 'pb', 5)} ondragend={vizDragEnd}
          ondragover={(e) => vizDragOver(e, 'pb', 5)} ondragleave={vizDragLeave}
          ondrop={(e) => vizDrop(e, 'pb', 5)}>
          <summary><span class="drag-handle">⋮⋮</span> Emittance Heatmap</summary>
          <div class="chart-section heatmap-wrap">
            <canvas bind:this={pbEmittanceHeatCanvas}></canvas>
          </div>
        </details>
      </div>

      {/if}

      {#if particleSubTab === 'accelerator'}

      <!-- ── Accelerator Equations ───────────────────────── -->
      <details class="equations-section">
        <summary><h3>Accelerator Design Equations</h3></summary>
        <div class="equation-block">
          <div class="equation">
            <span class="eq-var">KE</span> = <span class="eq-var">G</span> &middot; <span class="eq-var">L</span>
          </div>
          <div class="eq-label">Particle kinetic energy from accelerating gradient &times; length</div>
          <div class="eq-desc">
            <span class="eq-var-sm">G</span> = gradient (MV/m) &middot;
            <span class="eq-var-sm">L</span> = accelerator length (m)
          </div>
        </div>
        <div class="equation-block" style="margin-top: 0.75rem;">
          <div class="equation">
            <span class="eq-var">&epsilon;<sub>n</sub></span> = <span class="eq-var">&beta;&gamma;</span> &middot; <span class="eq-var">r<sub>0</sub></span> &middot; <span class="eq-var">&theta;</span>
          </div>
          <div class="eq-label">Normalized emittance &mdash; derived from fixed divergence (Liouville)</div>
          <div class="eq-desc">
            <span class="eq-var-sm">&theta;</span> = 5&times;10<sup>-7</sup> rad (fixed) &middot;
            <span class="eq-var-sm">&beta;&gamma;</span> = relativistic factor &middot;
            <span class="eq-var-sm">r<sub>0</sub></span> = exit beam radius
          </div>
        </div>
        <div class="equation-block" style="margin-top: 0.75rem;">
          <div class="equation">
            <span class="eq-var">L<sub>max</sub></span> = <span class="eq-var">r<sub>t</sub></span> &middot; <span class="eq-var">r<sub>0</sub></span> / <span class="eq-var">&epsilon;</span>
          </div>
          <div class="eq-label">Max range for a given spot &mdash; emittance feasibility limit</div>
          <div class="eq-desc">
            <span class="eq-var-sm">r<sub>t</sub></span> = target spot radius &middot;
            <span class="eq-var-sm">&epsilon;</span> = geometric emittance (&epsilon;<sub>n</sub>/&beta;&gamma;)
          </div>
        </div>
      </details>

      <!-- ── Accelerator Inputs ────────────────────────────── -->
      <div class="calc-panel">
        <div class="calc-grid">
          <SliderInput label="L — Accel. Length ({accLength} m)" bind:value={accLength} min={1} max={500} step={1} />
          <SliderInput label="G — Gradient ({accGradient} MV/m)" bind:value={accGradient} min={1} max={100} step={1} />
          <div class="eq-hint">KE = G &times; L = <strong>{formatParticleEnergy(accParticleKE)}</strong></div>
          <SliderInput label="Pᵢₙ — Elec. Power ({formatPowerCompact(accPowerIn)})" bind:value={accPowerIn} min={0.1} max={100000} step={0.1} log />
          <div class="eq-hint">&eta; = 30% &rarr; P_beam = <strong>{formatPowerCompact(accBeamPower)}</strong>, I = <strong>{formatCurrent(accCurrent)}</strong></div>
          <SliderInput label="d₀ — Exit ⌀ ({formatCm(accExitDiam)})" bind:value={accExitDiam} min={0.02} max={10} step={0.01} log />
          <SliderInput label="rₜ — Target Spot ({formatCm(accTargetSpotR)})" bind:value={accTargetSpotR} min={0.05} max={5} step={0.01} log />
          <div class="eq-hint">&theta; = 5&times;10⁻⁷ rad (fixed) &rarr; &epsilon;ₙ = <strong>{accNormEmittance.toFixed(3)} &mu;m&middot;rad</strong></div>
        </div>

        <!-- ── Derived Values ──────────────────────────────── -->
        <details class="results" open>
          <summary class="results-toggle">Derived Values</summary>
          <div class="result-row">
            <span class="result-label">Particle energy (KE = G&times;L)</span>
            <span class="result-value">{formatParticleEnergy(accParticleKE)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Beam power (P<sub>beam</sub> = 0.3 &times; P<sub>in</sub>)</span>
            <span class="result-value">{formatPowerCompact(accBeamPower)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Beam current (I = P/KE)</span>
            <span class="result-value">{formatCurrent(accCurrent)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Divergence (&theta;) — fixed</span>
            <span class="result-value">{ACC_DIVERGENCE_URAD} &mu;rad</span>
          </div>
          <div class="result-row">
            <span class="result-label">Norm. emittance (&epsilon;<sub>n</sub> = &beta;&gamma; &middot; r₀ &middot; &theta;)</span>
            <span class="result-value">{accNormEmittance.toFixed(3)} &mu;m&middot;rad</span>
          </div>
          <div class="result-row">
            <span class="result-label">Geom. emittance (&epsilon; = &theta; &middot; r₀)</span>
            <span class="result-value">{(accGeomEmittance * 1e9).toFixed(2)} nm&middot;rad</span>
          </div>
          <div class="result-row">
            <span class="result-label">Perveance (K)</span>
            <span class="result-value">{accPerveance.toExponential(2)}</span>
          </div>
          <div class="result-row">
            <span class="result-label">Relativistic &beta;&gamma;</span>
            <span class="result-value">{accBetaGamma.toFixed(3)}</span>
          </div>
          <div class="result-divider"></div>
          <div class="result-row primary">
            <span class="result-label">Max effective range</span>
            <span class="result-value">{accMaxRange > 0 ? formatRangeLabel(accMaxRange / 1000) : 'N/A — insufficient power'}</span>
          </div>
          <div class="result-row" style="margin-top: 0.25rem;">
            <span class="result-label" style="font-size: 0.7rem;">Target: 33 kJ in {formatCm(accTargetSpotR * 2)} spot in 0.5 s ({(ACC_TARGET_POWER / 1000).toFixed(0)} kW absorbed)</span>
            <span class="result-value"></span>
          </div>
        </details>
      </div>

      <!-- ── Spot Diameter vs Range Chart ───────────────────── -->
      <details class="viz-toggle" open>
        <summary>Spot vs Range</summary>
        <div class="chart-section" style="margin-top: 0.5rem;">
          <canvas bind:this={accChartCanvas}></canvas>
        </div>
      </details>

      {/if}

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

  /* ── Equations (collapsible) ─────────────────────── */
  .equations-section {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 0.75rem 1.5rem;
    margin-bottom: 1rem;
  }

  .equations-section summary {
    cursor: pointer;
    list-style: none;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .equations-section summary::-webkit-details-marker {
    display: none;
  }

  .equations-section summary::before {
    content: '▸';
    font-size: 0.85rem;
    color: var(--text-dim);
    transition: transform 0.15s;
  }

  .equations-section[open] summary::before {
    transform: rotate(90deg);
  }

  .equations-section summary h3 {
    margin: 0;
  }

  .equations-section[open] > :not(summary) {
    margin-top: 0.75rem;
  }

  .equations-section h3 {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.85rem;
    color: var(--text-dim);
    margin-bottom: 0;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .equations-section[open] h3 {
    color: var(--text);
    margin-bottom: 0;
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
    min-width: 0;
  }

  .calc-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
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

  /* ── Results (collapsible) ────────────────────────── */
  .results {
    border-top: 1px solid var(--border);
    padding-top: 0.75rem;
  }

  .results-toggle {
    cursor: pointer;
    list-style: none;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.75rem;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    padding-bottom: 0.5rem;
  }

  .results-toggle::-webkit-details-marker {
    display: none;
  }

  .results-toggle::before {
    content: '▸';
    font-size: 0.85rem;
    color: var(--text-dim);
    transition: transform 0.15s;
  }

  details.results[open] > .results-toggle::before {
    transform: rotate(90deg);
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
    margin-bottom: 0.25rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .bar-note {
    color: var(--text-dim);
    font-size: 0.7rem;
    font-style: italic;
    margin-bottom: 1rem;
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

  /* ── Visualization grid ──────────────────────────── */
  .viz-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
    margin-top: 1rem;
  }

  .viz-toggle {
    min-width: 0;
  }
  .viz-toggle > summary {
    cursor: pointer;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.75rem;
    color: var(--text-dim);
    padding: 0.3rem 0.5rem;
    list-style: none;
    user-select: none;
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .viz-toggle > summary::-webkit-details-marker { display: none; }
  .viz-toggle > summary::before {
    content: '▸';
    font-size: 0.65rem;
    transition: transform 0.15s;
  }
  .viz-toggle[open] > summary::before {
    transform: rotate(90deg);
  }
  .viz-toggle > summary:hover {
    color: var(--text);
  }
  .drag-handle {
    cursor: grab;
    color: var(--border);
    font-size: 0.7rem;
    letter-spacing: -2px;
    transition: color 0.15s;
  }
  .viz-toggle > summary:hover .drag-handle {
    color: var(--text-dim);
  }
  .viz-toggle:global(.viz-dragging) {
    opacity: 0.4;
  }
  .viz-toggle.viz-drag-over {
    outline: 2px dashed var(--accent);
    outline-offset: -2px;
    border-radius: 8px;
  }

  /* ── Chart section ────────────────────────────────── */
  .chart-section {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem;
    min-width: 0;
  }

  .heatmap-wrap canvas {
    width: 100%;
    height: auto;
  }

  .plotly-3d-container {
    width: 100%;
    height: 520px;
  }

  /* ── Particle Sub-Tabs ────────────────────────────── */
  .particle-sub-tabs {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1.25rem;
  }

  .psub-btn {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text-dim);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.75rem;
    font-weight: 500;
    padding: 0.4rem 0.8rem;
    cursor: pointer;
    transition: background 0.15s, color 0.15s, border-color 0.15s;
  }

  .psub-btn:hover {
    color: var(--text);
    border-color: var(--text-dim);
  }

  .psub-btn.active {
    background: var(--accent);
    color: var(--bg);
    border-color: var(--accent);
    font-weight: 600;
  }

  /* ── Equation hints inline in calc-grid ──────────── */
  .eq-hint {
    grid-column: 1 / -1;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.72rem;
    color: var(--text-dim);
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 5px;
    padding: 0.3rem 0.6rem;
    margin: -0.5rem 0 0.25rem;
  }

  .eq-hint strong {
    color: var(--accent);
    font-weight: 600;
  }

  /* ── Feasibility Warnings ─────────────────────────── */
  .feasibility-warnings {
    margin-top: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .feasibility-item {
    display: flex;
    align-items: flex-start;
    gap: 0.6rem;
    padding: 0.6rem 0.8rem;
    border-radius: 6px;
    border: 1px solid;
  }

  .feasibility-item.error {
    background: rgba(252, 129, 129, 0.08);
    border-color: rgba(252, 129, 129, 0.3);
  }

  .feasibility-item.warning {
    background: rgba(237, 137, 54, 0.08);
    border-color: rgba(237, 137, 54, 0.3);
  }

  .feasibility-item.ok {
    background: rgba(104, 211, 145, 0.06);
    border-color: rgba(104, 211, 145, 0.2);
  }

  .feasibility-icon {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.85rem;
    font-weight: 700;
    flex-shrink: 0;
    width: 1.2rem;
    text-align: center;
  }

  .feasibility-item.error .feasibility-icon { color: #fc8181; }
  .feasibility-item.warning .feasibility-icon { color: #ed8936; }
  .feasibility-item.ok .feasibility-icon { color: #68d391; }

  .feasibility-text {
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
  }

  .feasibility-label {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.78rem;
    font-weight: 600;
  }

  .feasibility-item.error .feasibility-label { color: #fc8181; }
  .feasibility-item.warning .feasibility-label { color: #ed8936; }
  .feasibility-item.ok .feasibility-label { color: #68d391; }

  .feasibility-detail {
    font-family: 'DM Sans', sans-serif;
    font-size: 0.75rem;
    color: var(--text-dim);
    line-height: 1.4;
  }

  /* ── Responsive ─────────────────────────────────── */
  @media (max-width: 1200px) {
    .viz-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (max-width: 800px) {
    .viz-grid {
      grid-template-columns: 1fr;
    }
    .calc-grid {
      grid-template-columns: 1fr;
    }
    .pen-results {
      grid-template-columns: repeat(2, 1fr);
    }
  }
</style>
