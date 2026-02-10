<script lang="ts">
  import { Chart, registerables } from 'chart.js';
  import materialData from './data/material-breakdown.json';
  import resourceData from './data/raw-resource-requirements.json';
  import constraintData from './data/production-constraints.json';
  import logisticsData from './data/logistics-vehicles.json';

  Chart.register(...registerables);

  const C = {
    text: '#e2e8f0',
    textDim: '#8492a6',
    border: '#2a3142',
    surface: '#161b22',
    accent: '#60a5fa',
    red: '#f87171',
    green: '#4ade80',
    yellow: '#fbbf24',
    purple: '#c084fc',
    orange: '#fb923c',
    pink: '#f472b6',
    cyan: '#22d3ee',
    teal: '#2dd4bf',
  };

  Chart.defaults.color = C.textDim;
  Chart.defaults.borderColor = C.border;
  Chart.defaults.font.family = "'DM Sans', sans-serif";

  const axisFont = { family: "'JetBrains Mono', monospace" as const, size: 11 };
  const titleFont = { family: "'JetBrains Mono', monospace" as const, size: 13, weight: 600 as const };

  // ── Data references ────────────────────────────────
  const baseline = materialData.classes[0];
  const carrier = materialData.classes[1];
  const baselineRes = resourceData.classes[0];
  const carrierRes = resourceData.classes[1];

  // ── Chart 1: Baseline Material Breakdown (pie/doughnut) ──
  const baselineColors = [C.accent, C.orange, C.red, C.teal, C.yellow, C.pink, C.purple, C.cyan, C.green];

  let canvas1: HTMLCanvasElement = $state(null!);

  $effect(() => {
    if (!canvas1) return;
    const chart = new Chart(canvas1, {
      type: 'doughnut',
      data: {
        labels: baseline.materials.map(m => m.name),
        datasets: [{
          data: baseline.materials.map(m => m.mass_kg),
          backgroundColor: baselineColors.map(c => c + 'cc'),
          borderColor: baselineColors,
          borderWidth: 1,
        }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.2,
        plugins: {
          title: { display: true, text: `Baseline Material Breakdown (${(baseline.dryMass_kg / 1000).toFixed(0)}t dry)`, color: C.text, font: titleFont },
          legend: {
            position: 'right',
            labels: { color: C.textDim, font: { size: 10 }, padding: 8 },
          },
          tooltip: {
            backgroundColor: C.surface,
            borderColor: C.border,
            borderWidth: 1,
            titleColor: C.text,
            bodyColor: C.textDim,
            callbacks: {
              label: (ctx: any) => {
                const val = ctx.parsed;
                const pct = ((val / baseline.dryMass_kg) * 100).toFixed(1);
                return ` ${val.toLocaleString()} kg (${pct}%)`;
              },
            },
          },
        },
      },
    });
    return () => chart.destroy();
  });

  // ── Chart 2: Carrier Material Breakdown (doughnut) ──
  const carrierColors = [C.accent, C.orange, C.cyan, C.purple, C.pink, C.teal, C.green];

  let canvas2: HTMLCanvasElement = $state(null!);

  $effect(() => {
    if (!canvas2) return;
    const chart = new Chart(canvas2, {
      type: 'doughnut',
      data: {
        labels: carrier.materials.map(m => m.name),
        datasets: [{
          data: carrier.materials.map(m => m.mass_kg),
          backgroundColor: carrierColors.map(c => c + 'cc'),
          borderColor: carrierColors,
          borderWidth: 1,
        }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.2,
        plugins: {
          title: { display: true, text: `Carrier Material Breakdown (${(carrier.dryMass_kg / 1e6).toFixed(0)}kt dry)`, color: C.text, font: titleFont },
          legend: {
            position: 'right',
            labels: { color: C.textDim, font: { size: 10 }, padding: 8 },
          },
          tooltip: {
            backgroundColor: C.surface,
            borderColor: C.border,
            borderWidth: 1,
            titleColor: C.text,
            bodyColor: C.textDim,
            callbacks: {
              label: (ctx: any) => {
                const val = ctx.parsed;
                const pct = ((val / carrier.dryMass_kg) * 100).toFixed(1);
                return ` ${(val / 1e6).toFixed(1)}M kg (${pct}%)`;
              },
            },
          },
        },
      },
    });
    return () => chart.destroy();
  });

  // ── Chart 3: Raw Resources — Baseline (horizontal bar) ──
  const allBaselineResources = [...baselineRes.bulkOres, ...baselineRes.industrialInputs];

  let canvas3: HTMLCanvasElement = $state(null!);

  $effect(() => {
    if (!canvas3) return;
    const sorted = [...allBaselineResources].sort((a, b) => b.mass_kg - a.mass_kg);
    const chart = new Chart(canvas3, {
      type: 'bar',
      data: {
        labels: sorted.map(r => r.name),
        datasets: [{
          data: sorted.map(r => r.mass_kg),
          backgroundColor: sorted.map((_, i) => {
            const colors = [C.accent, C.orange, C.green, C.red, C.teal, C.yellow, C.purple, C.cyan, C.pink, C.accent, C.orange, C.green];
            return colors[i % colors.length] + 'aa';
          }),
          borderColor: sorted.map((_, i) => {
            const colors = [C.accent, C.orange, C.green, C.red, C.teal, C.yellow, C.purple, C.cyan, C.pink, C.accent, C.orange, C.green];
            return colors[i % colors.length];
          }),
          borderWidth: 1,
        }],
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.4,
        scales: {
          x: {
            title: { display: true, text: 'Mass (kg)', color: C.textDim, font: axisFont },
            grid: { color: C.border },
            ticks: { color: C.textDim, callback: (val: any) => (Number(val) / 1000).toFixed(0) + 'k' },
          },
          y: {
            grid: { color: C.border },
            ticks: { color: C.textDim, font: { size: 10 } },
          },
        },
        plugins: {
          title: { display: true, text: 'Raw Resources per Baseline Ship (30t)', color: C.text, font: titleFont },
          legend: { display: false },
          tooltip: {
            backgroundColor: C.surface,
            borderColor: C.border,
            borderWidth: 1,
            titleColor: C.text,
            bodyColor: C.textDim,
            callbacks: {
              label: (ctx: any) => ` ${ctx.parsed.x.toLocaleString()} kg`,
            },
          },
        },
      },
    });
    return () => chart.destroy();
  });

  // ── Chart 4: Raw Resources — Carrier (horizontal bar) ──
  const allCarrierResources = [...carrierRes.bulkOres, ...carrierRes.industrialInputs];

  let canvas4: HTMLCanvasElement = $state(null!);

  $effect(() => {
    if (!canvas4) return;
    const sorted = [...allCarrierResources].sort((a, b) => b.mass_kg - a.mass_kg);
    const chart = new Chart(canvas4, {
      type: 'bar',
      data: {
        labels: sorted.map(r => r.name),
        datasets: [{
          data: sorted.map(r => r.mass_kg / 1000),
          backgroundColor: sorted.map((_, i) => {
            const colors = [C.accent, C.orange, C.green, C.red, C.teal, C.yellow, C.purple, C.cyan, C.pink, C.accent];
            return colors[i % colors.length] + 'aa';
          }),
          borderColor: sorted.map((_, i) => {
            const colors = [C.accent, C.orange, C.green, C.red, C.teal, C.yellow, C.purple, C.cyan, C.pink, C.accent];
            return colors[i % colors.length];
          }),
          borderWidth: 1,
        }],
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.4,
        scales: {
          x: {
            title: { display: true, text: 'Mass (metric tons)', color: C.textDim, font: axisFont },
            grid: { color: C.border },
            ticks: { color: C.textDim, callback: (val: any) => Number(val).toLocaleString() },
          },
          y: {
            grid: { color: C.border },
            ticks: { color: C.textDim, font: { size: 10 } },
          },
        },
        plugins: {
          title: { display: true, text: 'Raw Resources per Carrier (100kt)', color: C.text, font: titleFont },
          legend: { display: false },
          tooltip: {
            backgroundColor: C.surface,
            borderColor: C.border,
            borderWidth: 1,
            titleColor: C.text,
            bodyColor: C.textDim,
            callbacks: {
              label: (ctx: any) => ` ${ctx.parsed.x.toLocaleString()} metric tons`,
            },
          },
        },
      },
    });
    return () => chart.destroy();
  });

  // ── Chart 6 & 7: Hauls to Build One Ship ────────────────
  // Pick representative vehicles from trucks through ocean shipping
  const haulVehicles: { label: string; payload_t: number }[] = [
    { label: 'Box Truck (26 ft)', payload_t: 12.7 },
    { label: 'Flatbed Truck', payload_t: 20 },
    { label: 'Semi-Truck', payload_t: 36 },
    { label: 'Heavy Haul Truck', payload_t: 115 },
    { label: 'Single Railcar', payload_t: 100 },
    { label: 'Unit Train', payload_t: 10000 },
    { label: 'River Barge', payload_t: 1500 },
    { label: 'Feeder Ship', payload_t: 5000 },
    { label: 'Panamax Ship', payload_t: 65000 },
    { label: 'ULCS (24k TEU)', payload_t: 200000 },
  ];

  const baselineRaw_t = baselineRes.totalMinedInputs_kg / 1000; // 77 t
  const carrierRaw_t = carrierRes.totalMinedInputs_kg / 1000;   // 193,000 t

  const baselineHauls = haulVehicles.map(v => Math.ceil(baselineRaw_t / v.payload_t));
  const carrierHauls = haulVehicles.map(v => Math.ceil(carrierRaw_t / v.payload_t));

  const haulColors = [C.orange, C.orange, C.orange, C.red, C.yellow, C.yellow, C.cyan, C.accent, C.accent, C.accent];

  let canvas6: HTMLCanvasElement = $state(null!);
  let canvas7: HTMLCanvasElement = $state(null!);

  function makeHaulChart(canvas: HTMLCanvasElement, hauls: number[], title: string, rawTonnes: number) {
    return new Chart(canvas, {
      type: 'bar',
      data: {
        labels: haulVehicles.map(v => v.label),
        datasets: [{
          data: hauls,
          backgroundColor: haulColors.map(c => c + 'aa'),
          borderColor: haulColors,
          borderWidth: 1,
        }],
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.2,
        scales: {
          x: {
            type: 'logarithmic',
            title: { display: true, text: 'Number of Hauls', color: C.textDim, font: axisFont },
            grid: { color: C.border },
            ticks: {
              color: C.textDim,
              callback: (val: any) => {
                const num = Number(val);
                if ([1, 10, 100, 1000, 10000, 100000].includes(num)) return num.toLocaleString();
                return '';
              },
            },
            min: 1,
          },
          y: {
            grid: { color: C.border },
            ticks: { color: C.textDim, font: { size: 10 } },
          },
        },
        plugins: {
          title: { display: true, text: title, color: C.text, font: titleFont },
          legend: { display: false },
          tooltip: {
            backgroundColor: C.surface,
            borderColor: C.border,
            borderWidth: 1,
            titleColor: C.text,
            bodyColor: C.textDim,
            callbacks: {
              label: (ctx: any) => {
                const trips = ctx.parsed.x;
                const vehicle = haulVehicles[ctx.dataIndex];
                return ` ${trips.toLocaleString()} hauls × ${vehicle.payload_t.toLocaleString()}t = ${rawTonnes.toLocaleString()}t raw material`;
              },
            },
          },
        },
      },
    });
  }

  $effect(() => {
    if (!canvas6) return;
    const chart = makeHaulChart(canvas6, baselineHauls, 'Hauls to Build 1 Baseline Ship (77t raw)', baselineRaw_t);
    return () => chart.destroy();
  });

  $effect(() => {
    if (!canvas7) return;
    const chart = makeHaulChart(canvas7, carrierHauls, 'Hauls to Build 1 Carrier (193,000t raw)', carrierRaw_t);
    return () => chart.destroy();
  });

  // ── Chart 5: Raw-to-Finished Ratio Comparison ──
  let canvas5: HTMLCanvasElement = $state(null!);

  $effect(() => {
    if (!canvas5) return;
    const chart = new Chart(canvas5, {
      type: 'bar',
      data: {
        labels: ['Baseline (30t)', 'Carrier (100kt)'],
        datasets: [
          {
            label: 'Finished mass',
            data: [baseline.dryMass_kg / 1000, carrier.dryMass_kg / 1000],
            backgroundColor: C.green + 'aa',
            borderColor: C.green,
            borderWidth: 1,
          },
          {
            label: 'Processing waste',
            data: [
              (baselineRes.totalMinedInputs_kg - baseline.dryMass_kg) / 1000,
              (carrierRes.totalMinedInputs_kg - carrier.dryMass_kg) / 1000,
            ],
            backgroundColor: C.red + 'aa',
            borderColor: C.red,
            borderWidth: 1,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.6,
        scales: {
          x: {
            stacked: true,
            grid: { color: C.border },
            ticks: { color: C.textDim },
          },
          y: {
            stacked: true,
            title: { display: true, text: 'Mass (metric tons)', color: C.textDim, font: axisFont },
            grid: { color: C.border },
            ticks: { color: C.textDim, callback: (val: any) => Number(val).toLocaleString() },
          },
        },
        plugins: {
          title: { display: true, text: 'Raw Input vs Finished Output', color: C.text, font: titleFont },
          legend: { labels: { color: C.textDim, font: { size: 11 } } },
          tooltip: {
            backgroundColor: C.surface,
            borderColor: C.border,
            borderWidth: 1,
            titleColor: C.text,
            bodyColor: C.textDim,
            callbacks: {
              label: (ctx: any) => ` ${ctx.dataset.label}: ${ctx.parsed.y.toLocaleString()} t`,
            },
          },
        },
      },
    });
    return () => chart.destroy();
  });
</script>

<section class="production-chain">
  <h2>Production Chain</h2>
  <p class="subtitle">Raw resources, materials, and spacecraft construction scaling</p>

  <!-- ── Key Ratios ──────────────────────────────────── -->
  <div class="info-section">
    <h3>Key Ratios</h3>
    <div class="ratio-grid">
      <div class="ratio-card">
        <div class="ratio-value">{constraintData.keyRatios.rawToFinished_smallShip} : 1</div>
        <div class="ratio-label">raw &rarr; finished (30t ship)</div>
      </div>
      <div class="ratio-card">
        <div class="ratio-value">{constraintData.keyRatios.rawToFinished_carrierScale} : 1</div>
        <div class="ratio-label">raw &rarr; finished (100kt carrier)</div>
      </div>
      <div class="ratio-card">
        <div class="ratio-value">{constraintData.keyRatios.scalingModel}</div>
        <div class="ratio-label">scaling model</div>
      </div>
    </div>
  </div>

  <!-- ── Material Breakdowns (side by side) ──────────── -->
  <div class="chart-row">
    <div class="chart-section">
      <canvas bind:this={canvas1}></canvas>
    </div>
    <div class="chart-section">
      <canvas bind:this={canvas2}></canvas>
    </div>
  </div>

  <!-- ── Raw Resources (side by side) ────────────────── -->
  <div class="chart-row">
    <div class="chart-section">
      <canvas bind:this={canvas3}></canvas>
    </div>
    <div class="chart-section">
      <canvas bind:this={canvas4}></canvas>
    </div>
  </div>

  <!-- ── Raw vs Finished ─────────────────────────────── -->
  <div class="chart-section">
    <canvas bind:this={canvas5}></canvas>
  </div>

  <!-- ── Hauls to Build (side by side) ───────────────── -->
  <div class="chart-row">
    <div class="chart-section">
      <canvas bind:this={canvas6}></canvas>
    </div>
    <div class="chart-section">
      <canvas bind:this={canvas7}></canvas>
    </div>
  </div>
</section>

<style>
  .production-chain h2 {
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

  /* ── Info Section ────────────────────────────────── */
  .info-section {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem 1.5rem;
    margin-bottom: 1.5rem;
  }

  .info-section h3 {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1rem;
    color: var(--text);
    margin-bottom: 1rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .ratio-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
  }

  .ratio-card {
    text-align: center;
    padding: 0.75rem;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 8px;
  }

  .ratio-value {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1.3rem;
    color: var(--accent);
    font-weight: 700;
    margin-bottom: 0.25rem;
  }

  .ratio-label {
    color: var(--text-dim);
    font-size: 0.75rem;
  }

  /* ── Charts ──────────────────────────────────────── */
  .chart-section {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem;
    margin-bottom: 1.5rem;
  }

  .chart-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
  }

  .chart-row .chart-section {
    margin-bottom: 0;
  }

  @media (max-width: 700px) {
    .chart-row {
      grid-template-columns: 1fr;
    }
    .ratio-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }
</style>
