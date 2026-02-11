<script lang="ts">
  import { planes, ships, allVehicles, type Vehicle } from './vehicles';

  // Import all SVGs as URLs via Vite glob
  const planeSvgs: Record<string, string> = import.meta.glob(
    './third-party/planes/*.svg',
    { query: '?url', import: 'default', eager: true }
  ) as Record<string, string>;

  const shipSvgs: Record<string, string> = import.meta.glob(
    './third-party/ships/*.svg',
    { query: '?url', import: 'default', eager: true }
  ) as Record<string, string>;

  function getSvgUrl(v: Vehicle): string {
    const prefix = v.category === 'plane' ? './third-party/planes/' : './third-party/ships/';
    const key = prefix + v.file;
    return (v.category === 'plane' ? planeSvgs[key] : shipSvgs[key]) ?? '';
  }

  type FilterCategory = 'all' | 'plane' | 'ship';
  let filterCategory: FilterCategory = $state('plane');
  let selected = $state<string[]>([]);

  let filteredVehicles = $derived.by(() => {
    if (filterCategory === 'all') return allVehicles;
    if (filterCategory === 'plane') return planes;
    return ships;
  });

  let selectedVehicles = $derived(
    selected.map(id => allVehicles.find(v => v.id === id)!).filter(Boolean)
  );

  // The longest selected vehicle determines the scale
  let maxLength = $derived(
    selectedVehicles.length > 0
      ? Math.max(...selectedVehicles.map(v => v.lengthM))
      : 100
  );

  // Viewport width for comparison area (pixels)
  const COMPARE_WIDTH = 840;

  function pxPerMeter(): number {
    return COMPARE_WIDTH / (maxLength * 1.1); // 10% padding
  }

  function vehicleWidthPx(v: Vehicle): number {
    return v.lengthM * pxPerMeter();
  }

  function toggleVehicle(id: string) {
    if (selected.includes(id)) {
      selected = selected.filter(s => s !== id);
    } else {
      selected = [...selected, id];
    }
  }

  function clearAll() {
    selected = [];
  }

  // Scale ruler
  let rulerStepM = $derived.by(() => {
    const range = maxLength * 1.1;
    if (range > 500) return 100;
    if (range > 200) return 50;
    if (range > 100) return 25;
    if (range > 50) return 10;
    return 5;
  });

  let rulerMarks = $derived.by(() => {
    const marks: number[] = [];
    const range = maxLength * 1.1;
    for (let m = 0; m <= range; m += rulerStepM) {
      marks.push(m);
    }
    return marks;
  });
</script>

<div class="size-comparison">
  <h2>Size Comparison</h2>
  <p class="subtitle">Compare real-world sizes of military vehicles side by side</p>

  <div class="controls">
    <div class="filter-tabs">
      <button class:active={filterCategory === 'plane'} onclick={() => filterCategory = 'plane'}>Planes</button>
      <button class:active={filterCategory === 'ship'} onclick={() => filterCategory = 'ship'}>Ships</button>
      <button class:active={filterCategory === 'all'} onclick={() => filterCategory = 'all'}>All</button>
    </div>
    {#if selected.length > 0}
      <button class="clear-btn" onclick={clearAll}>Clear ({selected.length})</button>
    {/if}
  </div>

  <div class="vehicle-grid">
    {#each filteredVehicles as v (v.id)}
      <button
        class="vehicle-card"
        class:selected={selected.includes(v.id)}
        onclick={() => toggleVehicle(v.id)}
      >
        <div class="vehicle-thumb">
          <img src={getSvgUrl(v)} alt={v.name} />
        </div>
        <div class="vehicle-info">
          <span class="vehicle-name">{v.name}</span>
          <span class="vehicle-length">{v.lengthM} m</span>
        </div>
      </button>
    {/each}
  </div>

  {#if selectedVehicles.length > 0}
    <div class="comparison-area">
      <h3>Comparison ({selectedVehicles.length} selected)</h3>

      <div class="comparison-viewport">
        <!-- Scale ruler -->
        <div class="ruler" style="width: {COMPARE_WIDTH}px">
          {#each rulerMarks as m}
            <div class="ruler-mark" style="left: {m * pxPerMeter()}px">
              <div class="ruler-line"></div>
              <span class="ruler-label">{m}m</span>
            </div>
          {/each}
        </div>

        <!-- Vehicles stacked vertically, scaled proportionally -->
        <div class="vehicles-stack">
          {#each selectedVehicles as v (v.id)}
            <div class="compared-vehicle">
              <div class="compared-svg" style="width: {vehicleWidthPx(v)}px">
                <img src={getSvgUrl(v)} alt={v.name} />
              </div>
              <span class="compared-label">{v.name} ({v.lengthM}m)</span>
            </div>
          {/each}
        </div>
      </div>
    </div>
  {:else}
    <div class="empty-state">
      Select vehicles above to compare their sizes
    </div>
  {/if}
</div>

<style>
  .size-comparison {
    max-width: 900px;
  }

  h2 {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1.3rem;
    color: var(--accent);
    margin-bottom: 0.25rem;
  }

  .subtitle {
    color: var(--text-dim);
    font-size: 0.85rem;
    margin-bottom: 1.5rem;
  }

  h3 {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1rem;
    color: var(--text);
    margin-bottom: 1rem;
  }

  .controls {
    display: flex;
    align-items: center;
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .filter-tabs {
    display: flex;
    gap: 0;
    border: 1px solid var(--border);
    border-radius: 6px;
    overflow: hidden;
  }

  .filter-tabs button {
    background: var(--surface);
    border: none;
    border-right: 1px solid var(--border);
    color: var(--text-dim);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.8rem;
    padding: 0.4rem 1rem;
    cursor: pointer;
    transition: background 0.15s, color 0.15s;
  }

  .filter-tabs button:last-child {
    border-right: none;
  }

  .filter-tabs button:hover {
    color: var(--text);
    background: var(--surface2);
  }

  .filter-tabs button.active {
    background: var(--accent);
    color: var(--bg);
  }

  .clear-btn {
    background: none;
    border: 1px solid var(--red);
    color: var(--red);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.75rem;
    padding: 0.35rem 0.75rem;
    border-radius: 4px;
    cursor: pointer;
    transition: background 0.15s;
  }

  .clear-btn:hover {
    background: rgba(248, 113, 113, 0.1);
  }

  .vehicle-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: 0.5rem;
    margin-bottom: 2rem;
    max-height: 400px;
    overflow-y: auto;
    padding-right: 0.5rem;
  }

  .vehicle-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 0.6rem;
    cursor: pointer;
    transition: border-color 0.15s, background 0.15s;
    text-align: center;
  }

  .vehicle-card:hover {
    border-color: var(--accent);
    background: var(--surface2);
  }

  .vehicle-card.selected {
    border-color: var(--accent);
    background: var(--accent-glow);
  }

  .vehicle-thumb {
    width: 100%;
    height: 60px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 0.4rem;
  }

  .vehicle-thumb img {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
    filter: brightness(0.9);
  }

  .vehicle-info {
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
  }

  .vehicle-name {
    font-size: 0.7rem;
    font-weight: 600;
    color: var(--text);
    line-height: 1.2;
  }

  .vehicle-length {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    color: var(--text-dim);
  }

  .comparison-area {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1.25rem;
  }

  .comparison-viewport {
    overflow-x: auto;
    padding-bottom: 1rem;
  }

  .ruler {
    position: relative;
    height: 28px;
    margin-bottom: 0.75rem;
    border-bottom: 1px solid var(--border);
  }

  .ruler-mark {
    position: absolute;
    top: 0;
    height: 100%;
  }

  .ruler-line {
    width: 1px;
    height: 12px;
    background: var(--text-dim);
  }

  .ruler-label {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.6rem;
    color: var(--text-dim);
    display: block;
    margin-top: 2px;
    white-space: nowrap;
  }

  .vehicles-stack {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .compared-vehicle {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .compared-svg {
    height: 50px;
    flex-shrink: 0;
  }

  .compared-svg img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    object-position: left center;
  }

  .compared-label {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.7rem;
    color: var(--text-dim);
    padding-left: 2px;
  }

  .empty-state {
    text-align: center;
    color: var(--text-dim);
    font-size: 0.9rem;
    padding: 3rem 1rem;
    background: var(--surface);
    border: 1px dashed var(--border);
    border-radius: 8px;
  }

  @media (max-width: 700px) {
    .vehicle-grid {
      grid-template-columns: repeat(auto-fill, minmax(130px, 1fr));
    }
  }
</style>
