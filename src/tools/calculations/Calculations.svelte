<script lang="ts">
  type SubTab = 'projectile';
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

  /* ── Responsive ─────────────────────────────────── */
  @media (max-width: 700px) {
    .calc-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
