<script lang="ts">
  import VizGrid from '../../components/VizGrid.svelte';
  import SliderInput from '../../components/SliderInput.svelte';
  import enginesData from './data/engines.json';

  // ── Constants ──────────────────────────────────────────────
  const G0 = 9.81;
  const C = {
    text: '#e2e8f0',
    textDim: '#8492a6',
    border: '#2a3142',
    surface: '#161b22',
    bg: '#0e1117',
    accent: '#60a5fa',
    red: '#f87171',
    green: '#4ade80',
    yellow: '#fbbf24',
    purple: '#c084fc',
    orange: '#fb923c',
    cyan: '#22d3ee',
    teal: '#2dd4bf',
  };

  const PLANETS = ['mercury', 'venus', 'earth', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune'];

  // Flatten engine list for the dropdown
  interface Engine {
    name: string;
    category: string;
    propellant: string;
    thrust_N: number;
    mass_kg: number;
    isp_s: number;
  }
  const allEngines: Engine[] = enginesData.categories.flatMap(cat =>
    cat.engines.map(e => ({
      name: e.name,
      category: cat.label,
      propellant: e.propellant,
      thrust_N: e.thrust_N,
      mass_kg: e.mass_kg,
      isp_s: e.isp_s,
    }))
  );

  // ── State ──────────────────────────────────────────────────
  let startPlanet = $state('earth');
  let destPlanet = $state('mars');
  let shipMass = $state(100000); // kg — log slider from 20t to 700kt
  let selectedEngineIdx = $state(0);
  let thrusterCount = $state(1);

  const _y = new Date().getFullYear();
  let depStart = $state(`${_y}-01-01`);
  let depEnd = $state(`${_y + 2}-01-01`);
  let arrStart = $state(`${_y}-06-01`);
  let arrEnd = $state(`${_y + 3}-01-01`);
  let gridSteps = $state(40);

  let loading = $state(false);
  let errorMsg = $state('');

  interface PlotData {
    departureDates: string[];
    arrivalDates: string[];
    grid: {
      c3_km2s2: (number | null)[][];
      arrivalVinf_kms: (number | null)[][];
      totalDeltaV_kms: (number | null)[][];
      tof_days: (number | null)[][];
    };
  }
  let plotData: PlotData | null = $state(null);

  let selectedEngine = $derived(allEngines[selectedEngineIdx]);

  let minDv = $derived.by(() => {
    if (!plotData) return null;
    let min = Infinity, minI = 0, minJ = 0;
    const g = plotData.grid.totalDeltaV_kms;
    for (let i = 0; i < g.length; i++)
      for (let j = 0; j < g[i].length; j++) {
        const v = g[i][j];
        if (v !== null && !isNaN(v) && v < min) { min = v; minI = i; minJ = j; }
      }
    if (min === Infinity) return null;
    return {
      value: min,
      depDate: plotData.departureDates[minI],
      arrDate: plotData.arrivalDates[minJ],
      tof: plotData.grid.tof_days[minI][minJ],
    };
  });

  // Max practical mass ratio (90% propellant fraction)
  const MAX_MASS_RATIO = 10;

  // Combo max Δv (km/s) — determined solely by Isp and max mass ratio
  let comboMaxDv = $derived(selectedEngine
    ? (selectedEngine.isp_s * G0 * Math.log(MAX_MASS_RATIO)) / 1000
    : 0);

  // Propellant mass & stats at optimal transfer
  let optimalPropMass = $derived.by(() => {
    if (!minDv || !selectedEngine) return null;
    const dryMass = shipMass + thrusterCount * selectedEngine.mass_kg;
    const ve = selectedEngine.isp_s * G0;
    const dvMs = minDv.value * 1000;
    const massRatio = Math.exp(dvMs / ve);
    const propMass = dryMass * (massRatio - 1);
    const margin = comboMaxDv / minDv.value;
    return { dryMass, propMass, massRatio, totalMass: dryMass + propMass, margin };
  });

  // ── Canvas refs ────────────────────────────────────────────
  let dvCanvas: HTMLCanvasElement = $state(null!);
  let feasCanvas: HTMLCanvasElement = $state(null!);

  const VIZ_TITLES = ['Δv Porkchop Plot', 'Thruster Feasibility'];

  // ── Shared heatmap drawing ─────────────────────────────────
  const MARGIN = { l: 100, r: 80, t: 40, b: 90 };

  function lerpColor(a: string, b: string, t: number): string {
    const p = (h: string) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
    const ca = p(a), cb = p(b);
    return `rgb(${Math.round(ca[0] + (cb[0] - ca[0]) * t)},${Math.round(ca[1] + (cb[1] - ca[1]) * t)},${Math.round(ca[2] + (cb[2] - ca[2]) * t)})`;
  }

  function dvColor(dv: number, minVal: number, maxVal: number): string {
    const t = Math.sqrt(Math.max(0, Math.min(1, (dv - minVal) / (maxVal - minVal))));
    if (t < 0.25) return lerpColor(C.accent, C.cyan, t / 0.25);
    if (t < 0.5) return lerpColor(C.cyan, C.green, (t - 0.25) / 0.25);
    if (t < 0.75) return lerpColor(C.green, C.yellow, (t - 0.5) / 0.25);
    return lerpColor(C.yellow, C.red, (t - 0.75) / 0.25);
  }

  function feasColor(margin: number): string {
    // margin = comboMaxDv / requiredDv
    // <1 impossible, 1=bare minimum (red), 3+=plenty of margin (green)
    if (margin < 1)   return C.bg;
    if (margin < 1.5) return lerpColor(C.red, C.orange, (margin - 1) / 0.5);
    if (margin < 2)   return lerpColor(C.orange, C.yellow, (margin - 1.5) / 0.5);
    if (margin < 3)   return lerpColor(C.yellow, C.green, (margin - 2) / 1);
    return C.green;
  }

  function drawHeatmapAxes(
    ctx: CanvasRenderingContext2D,
    canvas: HTMLCanvasElement,
    data: PlotData,
    title: string,
  ) {
    const plotW = canvas.width - MARGIN.l - MARGIN.r;
    const plotH = canvas.height - MARGIN.t - MARGIN.b;
    const rows = data.grid.totalDeltaV_kms.length;
    const cols = data.grid.totalDeltaV_kms[0]?.length ?? 0;
    const cellW = plotW / cols;
    const cellH = plotH / rows;

    // X-axis labels
    ctx.fillStyle = C.textDim;
    ctx.font = "11px 'JetBrains Mono', monospace";
    const xN = Math.min(6, cols);
    for (let k = 0; k < xN; k++) {
      const j = Math.round((k / (xN - 1)) * (cols - 1));
      const x = MARGIN.l + (j + 0.5) * cellW;
      ctx.save();
      ctx.translate(x, MARGIN.t + plotH + 10);
      ctx.rotate(Math.PI / 4);
      ctx.textAlign = 'left';
      ctx.fillText(shortDate(data.arrivalDates[j]), 0, 0);
      ctx.restore();
    }

    // Y-axis labels
    ctx.textAlign = 'right';
    const yN = Math.min(6, rows);
    for (let k = 0; k < yN; k++) {
      const i = Math.round((k / (yN - 1)) * (rows - 1));
      ctx.fillText(shortDate(data.departureDates[i]), MARGIN.l - 8, MARGIN.t + (i + 0.5) * cellH + 4);
    }

    // Axis titles
    ctx.fillStyle = C.text;
    ctx.font = "12px 'JetBrains Mono', monospace";
    ctx.textAlign = 'center';
    ctx.fillText('Arrival Date', MARGIN.l + plotW / 2, canvas.height - 5);
    ctx.save();
    ctx.translate(14, MARGIN.t + plotH / 2);
    ctx.rotate(-Math.PI / 2);
    ctx.fillText('Departure Date', 0, 0);
    ctx.restore();

    // Title
    ctx.font = "bold 13px 'JetBrains Mono', monospace";
    ctx.textAlign = 'center';
    ctx.fillText(title, MARGIN.l + plotW / 2, MARGIN.t - 12);
  }

  function drawColorBar(
    ctx: CanvasRenderingContext2D,
    canvas: HTMLCanvasElement,
    labels: string[],
    colorFn: (t: number) => string,
  ) {
    const plotW = canvas.width - MARGIN.l - MARGIN.r;
    const plotH = canvas.height - MARGIN.t - MARGIN.b;
    const barX = MARGIN.l + plotW + 20;
    const barW = 18;

    for (let py = 0; py < plotH; py++) {
      ctx.fillStyle = colorFn(py / plotH);
      ctx.fillRect(barX, MARGIN.t + py, barW, 1);
    }
    ctx.strokeStyle = C.border;
    ctx.strokeRect(barX, MARGIN.t, barW, plotH);

    ctx.fillStyle = C.textDim;
    ctx.font = "10px 'JetBrains Mono', monospace";
    ctx.textAlign = 'left';
    for (let k = 0; k < labels.length; k++) {
      const y = MARGIN.t + (k / (labels.length - 1)) * plotH;
      ctx.fillText(labels[k], barX + barW + 4, y + 4);
    }
  }

  // ── Draw Δv heatmap ────────────────────────────────────────
  $effect(() => {
    if (!dvCanvas || !plotData) return;
    const ctx = dvCanvas.getContext('2d')!;
    const grid = plotData.grid.totalDeltaV_kms;
    const rows = grid.length, cols = grid[0]?.length ?? 0;
    if (!rows || !cols) return;

    let gMin = Infinity, gMax = -Infinity;
    for (const row of grid) for (const v of row) {
      if (v !== null && !isNaN(v)) { if (v < gMin) gMin = v; if (v > gMax) gMax = v; }
    }
    const colorMax = Math.min(gMax, gMin * 5);

    const plotW = dvCanvas.width - MARGIN.l - MARGIN.r;
    const plotH = dvCanvas.height - MARGIN.t - MARGIN.b;
    const cellW = plotW / cols, cellH = plotH / rows;

    ctx.fillStyle = C.surface;
    ctx.fillRect(0, 0, dvCanvas.width, dvCanvas.height);

    for (let i = 0; i < rows; i++) for (let j = 0; j < cols; j++) {
      const v = grid[i][j];
      ctx.fillStyle = (v === null || isNaN(v)) ? C.bg : dvColor(v, gMin, colorMax);
      ctx.fillRect(MARGIN.l + j * cellW, MARGIN.t + i * cellH, Math.ceil(cellW), Math.ceil(cellH));
    }

    // Mark minimum
    if (minDv) {
      for (let i = 0; i < rows; i++) for (let j = 0; j < cols; j++) {
        if (grid[i][j] !== null && Math.abs((grid[i][j] as number) - minDv.value) < 0.01) {
          ctx.strokeStyle = '#ffffff';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.arc(MARGIN.l + (j + 0.5) * cellW, MARGIN.t + (i + 0.5) * cellH, Math.min(cellW, cellH) * 0.4, 0, Math.PI * 2);
          ctx.stroke();
          i = rows; break; // done
        }
      }
    }

    drawHeatmapAxes(ctx, dvCanvas, plotData,
      `${capitalize(startPlanet)} → ${capitalize(destPlanet)} Total Δv (km/s)`);

    drawColorBar(ctx, dvCanvas,
      Array.from({ length: 5 }, (_, k) => (gMin + (k / 4) * (colorMax - gMin)).toFixed(1)),
      (t) => dvColor(gMin + t * (colorMax - gMin), gMin, colorMax));
  });

  // ── Draw feasibility heatmap ───────────────────────────────
  $effect(() => {
    if (!feasCanvas || !plotData || !selectedEngine) return;
    const ctx = feasCanvas.getContext('2d')!;
    const grid = plotData.grid.totalDeltaV_kms;
    const rows = grid.length, cols = grid[0]?.length ?? 0;
    if (!rows || !cols) return;

    const maxDvKms = comboMaxDv; // km/s

    const plotW = feasCanvas.width - MARGIN.l - MARGIN.r;
    const plotH = feasCanvas.height - MARGIN.t - MARGIN.b;
    const cellW = plotW / cols, cellH = plotH / rows;

    ctx.fillStyle = C.surface;
    ctx.fillRect(0, 0, feasCanvas.width, feasCanvas.height);

    for (let i = 0; i < rows; i++) for (let j = 0; j < cols; j++) {
      const dv = grid[i][j];
      if (dv === null || isNaN(dv) || dv <= 0) {
        ctx.fillStyle = C.bg;
      } else {
        const margin = maxDvKms / dv;
        ctx.fillStyle = feasColor(margin);
      }
      ctx.fillRect(MARGIN.l + j * cellW, MARGIN.t + i * cellH, Math.ceil(cellW), Math.ceil(cellH));
    }

    drawHeatmapAxes(ctx, feasCanvas, plotData,
      `${selectedEngine.name} ×${thrusterCount} — Δv margin (max ${comboMaxDv.toFixed(1)} km/s)`);

    // Color bar: 0x to 4x margin
    drawColorBar(ctx, feasCanvas,
      ['< 1× (impossible)', '1× (bare min)', '1.5×', '2×', '3×+ (good)'],
      (t) => feasColor(t * 4));
  });

  // ── Helpers ────────────────────────────────────────────────
  function shortDate(d: string): string {
    return d.split(' ')[0] ?? d;
  }
  function capitalize(s: string): string {
    return s.charAt(0).toUpperCase() + s.slice(1);
  }
  function fmtMass(kg: number): string {
    if (kg >= 1e6) return (kg / 1e6).toFixed(1) + ' kt';
    if (kg >= 1e3) return (kg / 1e3).toFixed(1) + ' t';
    return kg.toFixed(0) + ' kg';
  }

  // ── Fetch ──────────────────────────────────────────────────
  async function calculate() {
    if (startPlanet === destPlanet) { errorMsg = 'Start and destination must be different.'; return; }
    loading = true; errorMsg = ''; plotData = null;
    try {
      const res = await fetch('/api/orbit/porkchop', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          departurePlanet: startPlanet, arrivalPlanet: destPlanet,
          departureStart: depStart, departureEnd: depEnd,
          arrivalStart: arrStart, arrivalEnd: arrEnd,
          steps: gridSteps,
        }),
      });
      if (!res.ok) { const e = await res.json().catch(() => ({ error: res.statusText })); throw new Error(e.error); }
      plotData = await res.json();
    } catch (e: any) { errorMsg = e.message || 'Request failed'; }
    finally { loading = false; }
  }
</script>

<section class="thrusters">
  <h2>Thrusters</h2>
  <p class="subtitle">Orbital transfer & thruster design</p>

  <!-- ── Inputs ─────────────────────────────────────────── -->
  <div class="input-panel">
    <div class="input-row">
      <label>
        <span class="label-text">Start Planet</span>
        <select bind:value={startPlanet}>
          {#each PLANETS as p}
            <option value={p}>{capitalize(p)}</option>
          {/each}
        </select>
      </label>
      <label>
        <span class="label-text">Destination Planet</span>
        <select bind:value={destPlanet}>
          {#each PLANETS as p}
            <option value={p}>{capitalize(p)}</option>
          {/each}
        </select>
      </label>
      <label>
        <span class="label-text">Thruster</span>
        <select bind:value={selectedEngineIdx}>
          {#each allEngines as eng, i}
            <option value={i}>{eng.name} — {eng.propellant} (Isp {eng.isp_s}s)</option>
          {/each}
        </select>
      </label>
      <label>
        <span class="label-text">Count</span>
        <input type="number" class="count-input" bind:value={thrusterCount} min={1} max={1000} step={1} />
      </label>
    </div>

    <div class="slider-row-wrap">
      <SliderInput label="Ship Mass (kg)" bind:value={shipMass} min={20000} max={700000000} log={true} inputMax={700000000} />
    </div>

    <div class="input-row date-row">
      <label>
        <span class="label-text">Departure Start</span>
        <input type="date" bind:value={depStart} />
      </label>
      <label>
        <span class="label-text">Departure End</span>
        <input type="date" bind:value={depEnd} />
      </label>
      <label>
        <span class="label-text">Arrival Start</span>
        <input type="date" bind:value={arrStart} />
      </label>
      <label>
        <span class="label-text">Arrival End</span>
        <input type="date" bind:value={arrEnd} />
      </label>
      <label>
        <span class="label-text">Grid Steps</span>
        <input type="number" bind:value={gridSteps} min={5} max={100} step={5} />
      </label>
    </div>

    <button class="calc-btn" onclick={calculate} disabled={loading}>
      {loading ? 'Calculating…' : 'Calculate Transfer'}
    </button>

    {#if errorMsg}
      <p class="error">{errorMsg}</p>
    {/if}
  </div>

  <!-- ── Results ────────────────────────────────────────── -->
  {#if plotData}
    {#if minDv}
      <div class="stats-row">
        <div class="stat-card">
          <span class="stat-label">Required Δv (optimal)</span>
          <span class="stat-value">{minDv.value.toFixed(2)} km/s</span>
        </div>
        <div class="stat-card">
          <span class="stat-label">Combo Max Δv</span>
          <span class="stat-value">{comboMaxDv.toFixed(2)} km/s</span>
        </div>
        {#if optimalPropMass}
          <div class="stat-card">
            <span class="stat-label">Δv Margin</span>
            <span class="stat-value" style="color: {optimalPropMass.margin >= 3 ? '#4ade80' : optimalPropMass.margin >= 1 ? '#fbbf24' : '#f87171'}">
              {optimalPropMass.margin.toFixed(1)}×
            </span>
          </div>
        {/if}
        <div class="stat-card">
          <span class="stat-label">Best Departure</span>
          <span class="stat-value">{shortDate(minDv.depDate)}</span>
        </div>
        <div class="stat-card">
          <span class="stat-label">Best Arrival</span>
          <span class="stat-value">{shortDate(minDv.arrDate)}</span>
        </div>
        <div class="stat-card">
          <span class="stat-label">Transfer Time</span>
          <span class="stat-value">{minDv.tof ? Math.round(minDv.tof as number) + ' days' : '—'}</span>
        </div>
        {#if optimalPropMass}
          <div class="stat-card">
            <span class="stat-label">Fuel Required</span>
            <span class="stat-value">{fmtMass(optimalPropMass.propMass)}</span>
          </div>
          <div class="stat-card">
            <span class="stat-label">Fuel % of Ship Mass</span>
            <span class="stat-value">{(optimalPropMass.propMass / shipMass * 100).toFixed(1)}%</span>
          </div>
          <div class="stat-card">
            <span class="stat-label">Total Launch Mass</span>
            <span class="stat-value">{fmtMass(optimalPropMass.totalMass)}</span>
          </div>
        {/if}
      </div>
    {/if}

    <!-- Viz panels -->
    <VizGrid group="thruster" count={2} titles={VIZ_TITLES} columns={2}>
      {#snippet panel(id)}
        {#if id === 0}
          <div class="chart-section heatmap-wrap">
            <canvas bind:this={dvCanvas} width={700} height={550}></canvas>
          </div>
        {:else}
          <div class="chart-section heatmap-wrap">
            <canvas bind:this={feasCanvas} width={700} height={550}></canvas>
          </div>
        {/if}
      {/snippet}
    </VizGrid>
  {/if}
</section>

<style>
  /* ── Layout ──────────────────────────────────────── */
  .thrusters h2 {
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

  /* ── Input panel ─────────────────────────────────── */
  .input-panel {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem 1.5rem;
    margin-bottom: 1.5rem;
  }

  .input-row {
    display: flex;
    gap: 1.25rem;
    flex-wrap: wrap;
    margin-bottom: 1rem;
    align-items: flex-end;
  }

  .input-row label {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .label-text {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.75rem;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .input-panel select,
  .input-panel input[type="number"],
  .input-panel input[type="date"] {
    background: var(--surface2);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.85rem;
    padding: 0.4rem 0.6rem;
    min-width: 140px;
  }

  .input-panel .count-input {
    min-width: 60px;
    width: 70px;
  }

  .input-panel select:focus,
  .input-panel input:focus {
    outline: none;
    border-color: var(--accent);
  }

  .slider-row-wrap {
    margin-bottom: 1rem;
  }

  .date-row {
    margin-bottom: 1.25rem;
  }

  .calc-btn {
    background: var(--accent);
    color: #0e1117;
    border: none;
    border-radius: 6px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.85rem;
    font-weight: 600;
    padding: 0.5rem 1.5rem;
    cursor: pointer;
    transition: opacity 0.2s;
  }

  .calc-btn:hover { opacity: 0.85; }
  .calc-btn:disabled { opacity: 0.5; cursor: wait; }

  .error {
    color: var(--red);
    font-size: 0.85rem;
    margin-top: 0.75rem;
  }

  /* ── Stats row ───────────────────────────────────── */
  .stats-row {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
    margin-bottom: 1rem;
  }

  .stat-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 0.75rem 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
    min-width: 120px;
  }

  .stat-label {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .stat-value {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1rem;
    color: var(--accent);
    font-weight: 600;
  }

  /* ── Chart sections ──────────────────────────────── */
  .chart-section {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem;
    min-width: 0;
  }

  .heatmap-wrap {
    display: flex;
    justify-content: center;
  }

  .heatmap-wrap canvas {
    max-width: 100%;
    height: auto;
  }

  /* ── Responsive ──────────────────────────────────── */
  @media (max-width: 700px) {
    .input-row { flex-direction: column; }
    .stats-row { flex-direction: column; }
  }
</style>
