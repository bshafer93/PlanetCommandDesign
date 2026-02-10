<script lang="ts">
  import { Chart, registerables } from 'chart.js';
  import generatorData from './data/generator-comparison-10m3.json';
  import fuelData from './data/fuel-energy-density.json';
  import radiatorData from './data/radiator-cooling.json';
  import carrierData from './data/carrier-power-bounds.json';

  Chart.register(...registerables);

  type SubTab = 'generators' | 'thrusters';
  let activeSubTab: SubTab = $state('generators');

  // Colors matching global.css custom properties (Chart.js canvas can't read CSS vars)
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

  // Chart.js global dark theme defaults
  Chart.defaults.color = C.textDim;
  Chart.defaults.borderColor = C.border;
  Chart.defaults.font.family = "'DM Sans', sans-serif";

  // ── Chart 1: Volume vs Power Output ──────────────────────────
  const volumes = Array.from({ length: 100 }, (_, i) => i + 1);
  const techColors = [C.orange, C.green, C.cyan, C.purple, C.yellow];

  const chart1Datasets = generatorData.technologies.flatMap((tech, i) => {
    const color = techColors[i];
    const fillColor = color + '25'; // ~15% opacity hex
    return [
      {
        label: tech.name + ' (min)',
        data: volumes.map(v => tech.powerDensityMin_MWe_per_m3 * v),
        borderColor: color,
        borderWidth: 1.5,
        pointRadius: 0,
        fill: false,
        tension: 0,
      },
      {
        label: tech.name,
        data: volumes.map(v => tech.powerDensityMax_MWe_per_m3 * v),
        borderColor: color,
        borderWidth: 1.5,
        pointRadius: 0,
        fill: '-1',
        backgroundColor: fillColor,
        tension: 0,
      },
    ];
  });

  // ── Chart 2: Radiator Area vs Heat Rejection ────────────────
  const SIGMA = 5.670374419e-8;
  const EPSILON = radiatorData.emissivity;

  function heatRejected(T: number, area: number, sides: number): number {
    return (EPSILON * SIGMA * Math.pow(T, 4) * area * sides) / 1e6; // MW
  }

  const areas = Array.from({ length: 101 }, (_, i) => i * 50); // 0–5000 m²

  const chart2Datasets = [
    {
      label: '800 K (one-sided)',
      data: areas.map(a => heatRejected(800, a, 1)),
      borderColor: C.orange,
      borderWidth: 2,
      pointRadius: 0,
      fill: false,
    },
    {
      label: '800 K (both-sided)',
      data: areas.map(a => heatRejected(800, a, 2)),
      borderColor: C.orange,
      borderWidth: 2,
      borderDash: [6, 4],
      pointRadius: 0,
      fill: false,
    },
    {
      label: '1200 K (one-sided)',
      data: areas.map(a => heatRejected(1200, a, 1)),
      borderColor: C.red,
      borderWidth: 2,
      pointRadius: 0,
      fill: false,
    },
    {
      label: '1200 K (both-sided)',
      data: areas.map(a => heatRejected(1200, a, 2)),
      borderColor: C.red,
      borderWidth: 2,
      borderDash: [6, 4],
      pointRadius: 0,
      fill: false,
    },
  ];

  // ── Chart 3: Fuel Energy Density ─────────────────────────────
  const fuelLabels = fuelData.sources.map(s => s.name);
  const fuelValues = fuelData.sources.map(s =>
    (s as any).energyDensity ?? (s as any).energyDensityMax
  );
  const fuelColors = [C.orange, C.green, C.cyan];

  // ── Chart 4: Power Envelopes ─────────────────────────────────
  const envelopeLabels = carrierData.bounds.map(b => {
    const areaK = (b.radiatorArea_m2 / 1000).toFixed(0);
    return `${areaK}k m² / ${b.temperature_K} K`;
  });

  // ── Canvas refs & chart lifecycle ────────────────────────────
  let canvas1: HTMLCanvasElement = $state(null!);
  let canvas2: HTMLCanvasElement = $state(null!);
  let canvas3: HTMLCanvasElement = $state(null!);
  let canvas4: HTMLCanvasElement = $state(null!);

  const axisFont = { family: "'JetBrains Mono', monospace" as const, size: 11 };
  const titleFont = { family: "'JetBrains Mono', monospace" as const, size: 13, weight: 600 as const };

  $effect(() => {
    if (!canvas1 || activeSubTab !== 'generators') return;
    const chart = new Chart(canvas1, {
      type: 'line',
      data: { labels: volumes, datasets: chart1Datasets as any },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.8,
        scales: {
          x: {
            title: { display: true, text: 'Volume (m³)', color: C.textDim, font: axisFont },
            grid: { color: C.border },
            ticks: { color: C.textDim, maxTicksLimit: 10 },
          },
          y: {
            title: { display: true, text: 'Electric Power (MW)', color: C.textDim, font: axisFont },
            grid: { color: C.border },
            ticks: { color: C.textDim },
          },
        },
        plugins: {
          title: { display: true, text: 'Volume vs Electric Power Output', color: C.text, font: titleFont },
          legend: {
            labels: {
              color: C.textDim,
              font: { size: 11 },
              filter: (item) => !item.text?.includes('(min)'),
            },
          },
          tooltip: {
            backgroundColor: C.surface,
            borderColor: C.border,
            borderWidth: 1,
            titleColor: C.text,
            bodyColor: C.textDim,
          },
        },
      },
    });
    return () => chart.destroy();
  });

  $effect(() => {
    if (!canvas2 || activeSubTab !== 'generators') return;
    const chart = new Chart(canvas2, {
      type: 'line',
      data: { labels: areas, datasets: chart2Datasets as any },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.8,
        scales: {
          x: {
            title: { display: true, text: 'Radiator Area (m²)', color: C.textDim, font: axisFont },
            grid: { color: C.border },
            ticks: { color: C.textDim, maxTicksLimit: 10 },
          },
          y: {
            title: { display: true, text: 'Heat Rejected (MW)', color: C.textDim, font: axisFont },
            grid: { color: C.border },
            ticks: { color: C.textDim },
          },
        },
        plugins: {
          title: { display: true, text: 'Radiator Area vs Heat Rejection', color: C.text, font: titleFont },
          legend: { labels: { color: C.textDim, font: { size: 11 } } },
          tooltip: {
            backgroundColor: C.surface,
            borderColor: C.border,
            borderWidth: 1,
            titleColor: C.text,
            bodyColor: C.textDim,
          },
        },
      },
    });
    return () => chart.destroy();
  });

  $effect(() => {
    if (!canvas3 || activeSubTab !== 'generators') return;
    const chart = new Chart(canvas3, {
      type: 'bar',
      data: {
        labels: fuelLabels,
        datasets: [{
          data: fuelValues,
          backgroundColor: fuelColors.map(c => c + 'cc'),
          borderColor: fuelColors,
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
            type: 'logarithmic',
            title: { display: true, text: 'Energy Density (J/kg)', color: C.textDim, font: axisFont },
            grid: { color: C.border },
            ticks: {
              color: C.textDim,
              callback: (val: any) => {
                const num = Number(val);
                if (num === 0) return '0';
                const exp = Math.log10(num);
                if (Number.isInteger(exp)) return `10^${exp}`;
                return '';
              },
            },
            min: 1e6,
            max: 1e15,
          },
          y: {
            grid: { color: C.border },
            ticks: { color: C.textDim, font: { size: 11 } },
          },
        },
        plugins: {
          title: { display: true, text: 'Fuel Energy Density Comparison', color: C.text, font: titleFont },
          legend: { display: false },
          tooltip: {
            backgroundColor: C.surface,
            borderColor: C.border,
            borderWidth: 1,
            titleColor: C.text,
            bodyColor: C.textDim,
            callbacks: {
              label: (ctx: any) => {
                const val = ctx.parsed.x;
                return ` ${val.toExponential(1)} J/kg`;
              },
            },
          },
        },
      },
    });
    return () => chart.destroy();
  });

  $effect(() => {
    if (!canvas4 || activeSubTab !== 'generators') return;
    const chart = new Chart(canvas4, {
      type: 'bar',
      data: {
        labels: envelopeLabels,
        datasets: [
          {
            label: 'Min Power (GW)',
            data: carrierData.bounds.map(b => b.electricPowerMin_GW),
            backgroundColor: C.cyan + 'aa',
            borderColor: C.cyan,
            borderWidth: 1,
          },
          {
            label: 'Max Power (GW)',
            data: carrierData.bounds.map(b => b.electricPowerMax_GW),
            backgroundColor: C.purple + 'aa',
            borderColor: C.purple,
            borderWidth: 1,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.4,
        scales: {
          x: {
            grid: { color: C.border },
            ticks: { color: C.textDim, font: { size: 10 } },
          },
          y: {
            title: { display: true, text: 'Electric Power (GW)', color: C.textDim, font: axisFont },
            grid: { color: C.border },
            ticks: { color: C.textDim },
          },
        },
        plugins: {
          title: { display: true, text: 'Radiator-Limited Power Envelopes', color: C.text, font: titleFont },
          legend: { labels: { color: C.textDim, font: { size: 11 } } },
          tooltip: {
            backgroundColor: C.surface,
            borderColor: C.border,
            borderWidth: 1,
            titleColor: C.text,
            bodyColor: C.textDim,
          },
        },
      },
    });
    return () => chart.destroy();
  });
</script>

<section class="power-gen">
  <h2>Power & Propulsion</h2>
  <p class="subtitle">Generator and thruster design tools</p>

  <nav class="sub-tab-bar">
    <button
      class="sub-tab-btn"
      class:active={activeSubTab === 'generators'}
      onclick={() => activeSubTab = 'generators'}
    >
      Generators
    </button>
    <button
      class="sub-tab-btn"
      class:active={activeSubTab === 'thrusters'}
      onclick={() => activeSubTab = 'thrusters'}
    >
      Thrusters
    </button>
  </nav>

  <div class="sub-content">
    {#if activeSubTab === 'generators'}

      <!-- ── Governing Equations ──────────────────────── -->
      <div class="equations-section">
        <h3>Governing Equations</h3>

        <div class="equation-block">
          <div class="equation">
            <span class="eq-var">q</span> = <span class="eq-var">&epsilon;</span> <span class="eq-var">&sigma;</span> <span class="eq-var">T</span><sup>4</sup>
          </div>
          <div class="eq-label">Stefan-Boltzmann Law &mdash; radiative heat rejection per unit area</div>
          <div class="eq-desc">
            <span class="eq-var-sm">q</span> = radiated power (W/m&sup2;) &middot;
            <span class="eq-var-sm">&epsilon;</span> = emissivity &middot;
            <span class="eq-var-sm">&sigma;</span> = 5.67 &times; 10<sup>&minus;8</sup> W&middot;m<sup>&minus;2</sup>&middot;K<sup>&minus;4</sup> &middot;
            <span class="eq-var-sm">T</span> = temperature (K)
          </div>
        </div>

        <div class="equation-block">
          <div class="equation">
            <span class="eq-var">P</span> = <span class="eq-var">&rho;<sub>P</sub></span> &times; <span class="eq-var">V</span>
          </div>
          <div class="eq-label">Power from Volume &mdash; linear scaling with power density</div>
          <div class="eq-desc">
            <span class="eq-var-sm">P</span> = electric power output (MW) &middot;
            <span class="eq-var-sm">&rho;<sub>P</sub></span> = power density (MW/m&sup3;) &middot;
            <span class="eq-var-sm">V</span> = generator volume (m&sup3;)
          </div>
        </div>

        <div class="equation-block">
          <div class="equation">
            <span class="eq-var">e</span> = <span class="eq-var">E</span> / <span class="eq-var">m</span>
          </div>
          <div class="eq-label">Energy Density &mdash; energy per unit mass of fuel</div>
          <div class="eq-desc">
            <span class="eq-var-sm">e</span> = specific energy (J/kg) &middot;
            <span class="eq-var-sm">E</span> = total energy (J) &middot;
            <span class="eq-var-sm">m</span> = fuel mass (kg)
          </div>
        </div>
      </div>

      <!-- ── Chart 1: Volume vs Power ─────────────────── -->
      <div class="chart-section">
        <canvas bind:this={canvas1}></canvas>
      </div>

      <!-- ── Chart 2: Radiator Area vs Heat Rejection ── -->
      <div class="chart-section">
        <canvas bind:this={canvas2}></canvas>
      </div>

      <!-- ── Charts 3 & 4 side by side ────────────────── -->
      <div class="chart-row">
        <div class="chart-section">
          <canvas bind:this={canvas3}></canvas>
        </div>
        <div class="chart-section">
          <canvas bind:this={canvas4}></canvas>
        </div>
      </div>

    {:else}
      <div class="placeholder">
        <h3>Thrusters</h3>
        <p>Thruster design tools coming soon.</p>
      </div>
    {/if}
  </div>
</section>

<style>
  /* ── Layout ──────────────────────────────────────── */
  .power-gen h2 {
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
    margin-bottom: 1.25rem;
  }

  .equation-block:last-child {
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

  /* ── Placeholder ─────────────────────────────────── */
  .placeholder h3 {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1.1rem;
    color: var(--text);
    margin-bottom: 0.5rem;
  }

  .placeholder p {
    color: var(--text-dim);
    font-size: 0.9rem;
  }

  /* ── Responsive ──────────────────────────────────── */
  @media (max-width: 700px) {
    .chart-row {
      grid-template-columns: 1fr;
    }
  }
</style>
