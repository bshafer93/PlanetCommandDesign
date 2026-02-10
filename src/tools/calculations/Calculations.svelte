<script lang="ts">
  import { Chart, registerables } from 'chart.js';
  Chart.register(...registerables);

  type SubTab = 'projectile' | 'laser';
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
  let laserPower = $state(1);         // MW
  let laserRange = $state(100);       // km

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

  // ── Chart ──────────────────────────────────────────
  let laserCanvas = $state<HTMLCanvasElement>();

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

          <!-- Aperture -->
          <div class="field-group">
            <label class="field-label">Aperture (cm)</label>
            <div class="slider-row">
              <input type="range" min="5" max="200" step="1" bind:value={laserAperture} class="laser-slider" />
              <input type="number" bind:value={laserAperture} min="5" max="200" step="1" class="slider-num" />
            </div>
          </div>

          <!-- Wavelength -->
          <div class="field-group">
            <label class="field-label">Wavelength (nm)</label>
            <div class="slider-row">
              <input type="range" min="200" max="10600" step="1" bind:value={laserWavelength} class="laser-slider" />
              <input type="number" bind:value={laserWavelength} min="200" max="10600" step="1" class="slider-num" />
            </div>
          </div>

          <!-- Power -->
          <div class="field-group">
            <label class="field-label">Power (MW)</label>
            <div class="slider-row">
              <input type="range" min="0.1" max="100" step="0.1" bind:value={laserPower} class="laser-slider" />
              <input type="number" bind:value={laserPower} min="0.1" max="1000" step="0.1" class="slider-num" />
            </div>
          </div>

          <!-- Range -->
          <div class="field-group">
            <label class="field-label">Range (km)</label>
            <div class="slider-row">
              <input type="range" min="1" max="1000" step="1" bind:value={laserRange} class="laser-slider" />
              <input type="number" bind:value={laserRange} min="1" max="10000" step="1" class="slider-num" />
            </div>
          </div>

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

  /* ── Slider row ─────────────────────────────────── */
  .slider-row {
    display: flex;
    align-items: center;
    gap: 0.6rem;
  }

  .laser-slider {
    flex: 1;
    accent-color: var(--accent);
    height: 6px;
  }

  .slider-num {
    width: 80px;
    flex-shrink: 0;
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
