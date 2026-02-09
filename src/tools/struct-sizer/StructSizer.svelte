<script lang="ts">
  interface CppTypeInfo {
    size: number;
    color: string;
    note?: string;
  }

  interface Field {
    id: number;
    type: string;
    count: number;
    label: string;
  }

  const TYPES: Record<string, CppTypeInfo> = {
    'bool':               { size: 1, color: '#4ade80' },
    'char':               { size: 1, color: '#22d3ee' },
    'signed char':        { size: 1, color: '#22d3ee' },
    'unsigned char':      { size: 1, color: '#22d3ee' },
    'int8_t':             { size: 1, color: '#60a5fa' },
    'uint8_t':            { size: 1, color: '#60a5fa' },
    'int16_t':            { size: 2, color: '#818cf8' },
    'uint16_t':           { size: 2, color: '#818cf8' },
    'short':              { size: 2, color: '#818cf8' },
    'unsigned short':     { size: 2, color: '#818cf8' },
    'int':                { size: 4, color: '#c084fc' },
    'unsigned int':       { size: 4, color: '#c084fc' },
    'int32_t':            { size: 4, color: '#c084fc' },
    'uint32_t':           { size: 4, color: '#c084fc' },
    'long':               { size: 8, color: '#e879f9' },
    'unsigned long':      { size: 8, color: '#e879f9' },
    'long long':          { size: 8, color: '#e879f9' },
    'unsigned long long': { size: 8, color: '#e879f9' },
    'int64_t':            { size: 8, color: '#e879f9' },
    'uint64_t':           { size: 8, color: '#e879f9' },
    'float':              { size: 4, color: '#fb923c' },
    'double':             { size: 8, color: '#f87171' },
    'long double':        { size: 16, color: '#f43f5e' },
    'size_t':             { size: 8, color: '#fbbf24' },
    'ptrdiff_t':          { size: 8, color: '#fbbf24' },
    'void*':              { size: 8, color: '#f472b6' },
    'char*':              { size: 8, color: '#f472b6' },
    'std::string':        { size: 32, color: '#2dd4bf' },
    'std::vector<T>':     { size: 24, color: '#34d399' },
    'std::array<T,N>':    { size: 0, color: '#a3e635', note: 'size depends on T and N' },
    'std::unique_ptr<T>': { size: 8, color: '#38bdf8' },
    'std::shared_ptr<T>': { size: 16, color: '#0ea5e9' },
    'std::pair<A,B>':     { size: 16, color: '#a78bfa' },
    'std::optional<T>':   { size: 8, color: '#d946ef' },
    'std::function<>':    { size: 32, color: '#ec4899' },
  };

  const typeNames = Object.keys(TYPES);

  let fields = $state<Field[]>([
    { id: 0, type: 'int', count: 1, label: 'id' },
    { id: 1, type: 'double', count: 1, label: 'x' },
    { id: 2, type: 'double', count: 1, label: 'y' },
    { id: 3, type: 'bool', count: 1, label: 'active' },
  ]);
  let nextId = $state(4);
  let usePadding = $state(true);
  let structName = $state('MyStruct');

  function safeCount(n: number): number {
    return Math.max(1, n || 1);
  }

  function fieldTotalSize(f: Field): number {
    return TYPES[f.type].size * safeCount(f.count);
  }

  function getAlignedTotal(fieldList: Field[]): number {
    if (fieldList.length === 0) return 0;
    let maxAlign = 1;
    let offset = 0;
    for (const f of fieldList) {
      const fieldSize = TYPES[f.type].size;
      const align = Math.min(fieldSize || 1, 8);
      if (align > maxAlign) maxAlign = align;
      const count = safeCount(f.count);
      for (let i = 0; i < count; i++) {
        const padding = (align - (offset % align)) % align;
        offset += padding + fieldSize;
      }
    }
    const tailPadding = (maxAlign - (offset % maxAlign)) % maxAlign;
    return offset + tailPadding;
  }

  let rawTotal = $derived(fields.reduce((s, f) => s + fieldTotalSize(f), 0));
  let totalBytes = $derived(usePadding ? getAlignedTotal(fields) : rawTotal);
  let paddingBytes = $derived(totalBytes - rawTotal);

  function smartFormat(val: number): string {
    if (val === 0) return '0';
    if (val >= 1) return val.toLocaleString('en-US', { maximumFractionDigits: 2 });
    if (val >= 0.001) return val.toFixed(6).replace(/0+$/, '').replace(/\.$/, '');
    return val.toExponential(2);
  }

  let mbStr = $derived(smartFormat(totalBytes / (1024 * 1024)));
  let gbStr = $derived(smartFormat(totalBytes / (1024 * 1024 * 1024)));

  function addField() {
    fields.push({ id: nextId++, type: 'int', count: 1, label: '' });
  }

  function removeField(id: number) {
    fields = fields.filter(f => f.id !== id);
  }
</script>

<div class="struct-header">
  <span>struct</span>
  <input type="text" bind:value={structName} spellcheck="false">
  <span>{'{'}</span>
</div>

<div class="column-labels">
  <span>Type</span>
  <span>Count</span>
  <span>Label</span>
  <span style="text-align:right">Size</span>
  <span></span>
</div>

<div class="rows-container">
  {#each fields as field (field.id)}
    <div class="field-row">
      <select bind:value={field.type}>
        {#each typeNames as t}
          <option value={t}>{t}</option>
        {/each}
      </select>
      <input class="count-input" type="number" min="1" bind:value={field.count}>
      <input class="label-input" type="text" placeholder="field_name" bind:value={field.label} spellcheck="false">
      <div class="size-display">{fieldTotalSize(field)} B</div>
      <button class="remove-btn" onclick={() => removeField(field.id)} title="Remove">&times;</button>
    </div>
  {/each}
</div>

<button class="add-btn" onclick={addField}>
  <span style="font-size:1.1rem;">+</span> Add Field
</button>

<div class="struct-header" style="margin-top:0.75rem;">
  <span>{'};'}</span>
</div>

<div class="summary">
  {#if fields.length === 0}
    <div class="empty-state">Add fields above to see memory breakdown</div>
  {:else}
    <div class="summary-top">
      <div class="summary-title">Memory Breakdown</div>
    </div>
    <div class="total-sizes">
      <div class="size-unit">
        <span class="val">{totalBytes.toLocaleString()}</span>
        <span class="unit">bytes</span>
      </div>
      <span class="size-divider">/</span>
      <div class="size-unit secondary">
        <span class="val">{mbStr}</span>
        <span class="unit">MB</span>
      </div>
      <span class="size-divider">/</span>
      <div class="size-unit secondary">
        <span class="val">{gbStr}</span>
        <span class="unit">GB</span>
      </div>
    </div>
    <div style="margin-top:1.25rem;"></div>
    <div class="bar-container">
      {#each fields as f}
        {@const size = fieldTotalSize(f)}
        {@const pct = (size / totalBytes) * 100}
        {#if pct > 0}
          <div class="bar-segment" style="width:{pct}%;background:{TYPES[f.type].color};">
            <div class="tooltip">{f.label || f.type}: {size} B ({pct.toFixed(1)}%)</div>
          </div>
        {/if}
      {/each}
      {#if usePadding && paddingBytes > 0}
        {@const pct = (paddingBytes / totalBytes) * 100}
        <div class="bar-segment" style="width:{pct}%;background:repeating-linear-gradient(45deg,#2a3142,#2a3142 4px,#1c2231 4px,#1c2231 8px);">
          <div class="tooltip">padding: {paddingBytes} B ({pct.toFixed(1)}%)</div>
        </div>
      {/if}
    </div>
    <div class="legend">
      {#each fields as f}
        <div class="legend-item">
          <div class="legend-dot" style="background:{TYPES[f.type].color}"></div>
          <span class="lbl">{f.label || f.type}</span>
          <span class="sz">{fieldTotalSize(f)} B</span>
        </div>
      {/each}
      {#if usePadding && paddingBytes > 0}
        <div class="legend-item">
          <div class="legend-dot" style="background:repeating-linear-gradient(45deg,#2a3142,#2a3142 2px,#1c2231 2px,#1c2231 4px)"></div>
          <span class="lbl">padding</span>
          <span class="sz">{paddingBytes} B</span>
        </div>
      {/if}
    </div>
    <div class="padding-note">
      <label>
        <input type="checkbox" bind:checked={usePadding}>
        Estimate struct alignment padding
      </label>
      {#if usePadding && paddingBytes > 0}
        <div class="padding-result">+{paddingBytes} B padding</div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .struct-header {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 1.25rem;
    font-family: 'JetBrains Mono', monospace;
    color: var(--text-dim);
    font-size: 0.85rem;
  }

  .struct-header input {
    background: var(--surface);
    border: 1px solid var(--border);
    color: var(--accent);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.85rem;
    padding: 0.4rem 0.65rem;
    border-radius: 6px;
    outline: none;
    width: 160px;
    transition: border-color 0.2s;
  }

  .struct-header input:focus {
    border-color: var(--accent);
  }

  .column-labels {
    display: grid;
    grid-template-columns: 160px 80px 1fr 60px 44px;
    gap: 0.75rem;
    padding: 0 0.5rem 0.5rem;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: var(--text-dim);
    font-weight: 600;
  }

  .rows-container {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-bottom: 1.25rem;
  }

  .field-row {
    display: grid;
    grid-template-columns: 160px 80px 1fr 60px 44px;
    gap: 0.75rem;
    align-items: center;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 0.55rem 0.65rem;
    transition: border-color 0.2s, background 0.2s;
    animation: slideIn 0.2s ease-out;
  }

  @keyframes slideIn {
    from { opacity: 0; transform: translateY(-8px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .field-row:hover {
    border-color: #3a4560;
  }

  .field-row select,
  .field-row input {
    background: var(--surface2);
    border: 1px solid var(--border);
    color: var(--text);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.8rem;
    padding: 0.4rem 0.5rem;
    border-radius: 5px;
    outline: none;
    transition: border-color 0.2s;
  }

  .field-row select:focus,
  .field-row input:focus {
    border-color: var(--accent);
  }

  .field-row select { cursor: pointer; }

  .field-row .label-input {
    font-family: 'DM Sans', sans-serif;
    font-size: 0.85rem;
  }

  .field-row .count-input {
    text-align: center;
    width: 100%;
  }

  .field-row .size-display {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.8rem;
    color: var(--text-dim);
    text-align: right;
    white-space: nowrap;
  }

  .remove-btn {
    background: none;
    border: 1px solid transparent;
    color: var(--text-dim);
    cursor: pointer;
    border-radius: 5px;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.15s;
    font-size: 1.1rem;
  }

  .remove-btn:hover {
    color: var(--red);
    background: rgba(248, 113, 113, 0.1);
    border-color: rgba(248, 113, 113, 0.2);
  }

  .add-btn {
    background: var(--accent-glow);
    border: 1px dashed var(--accent);
    color: var(--accent);
    font-family: 'DM Sans', sans-serif;
    font-weight: 600;
    font-size: 0.85rem;
    padding: 0.65rem;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s;
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.4rem;
  }

  .add-btn:hover {
    background: rgba(96, 165, 250, 0.2);
  }

  .summary {
    margin-top: 2rem;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.5rem;
  }

  .summary-top {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    margin-bottom: 1.25rem;
  }

  .summary-title {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: var(--text-dim);
    font-weight: 600;
  }

  .total-sizes {
    display: flex;
    gap: 1.5rem;
    align-items: baseline;
    flex-wrap: wrap;
  }

  .size-unit {
    font-family: 'JetBrains Mono', monospace;
    display: flex;
    align-items: baseline;
    gap: 0.3rem;
  }

  .size-unit .val {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--text);
  }

  .size-unit .unit {
    font-size: 0.8rem;
    font-weight: 400;
    color: var(--text-dim);
  }

  .size-unit.secondary .val {
    font-size: 1rem;
    color: var(--text-dim);
  }

  .size-unit.secondary .unit {
    font-size: 0.7rem;
    color: #556077;
  }

  .size-divider {
    color: #2a3142;
    font-size: 1.2rem;
    user-select: none;
  }

  .bar-container {
    width: 100%;
    height: 36px;
    border-radius: 6px;
    overflow: hidden;
    display: flex;
    background: var(--surface2);
    margin-bottom: 1rem;
  }

  .bar-segment {
    height: 100%;
    transition: width 0.4s ease;
    position: relative;
    min-width: 0;
  }

  .bar-segment:first-child { border-radius: 6px 0 0 6px; }
  .bar-segment:last-child { border-radius: 0 6px 6px 0; }
  .bar-segment:only-child { border-radius: 6px; }

  .bar-segment:hover {
    filter: brightness(1.2);
  }

  .bar-segment .tooltip {
    display: none;
    position: absolute;
    bottom: calc(100% + 8px);
    left: 50%;
    transform: translateX(-50%);
    background: #1e2536;
    border: 1px solid var(--border);
    padding: 0.35rem 0.6rem;
    border-radius: 5px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.7rem;
    color: var(--text);
    white-space: nowrap;
    z-index: 10;
    pointer-events: none;
  }

  .bar-segment:hover .tooltip { display: block; }

  .legend {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem 1.25rem;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.78rem;
    color: var(--text-dim);
  }

  .legend-dot {
    width: 10px;
    height: 10px;
    border-radius: 3px;
    flex-shrink: 0;
  }

  .legend-item .lbl {
    font-family: 'DM Sans', sans-serif;
  }

  .legend-item .sz {
    font-family: 'JetBrains Mono', monospace;
    color: var(--text);
    font-size: 0.75rem;
  }

  .padding-note {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid var(--border);
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .padding-note label {
    font-size: 0.8rem;
    color: var(--text-dim);
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .padding-note input[type="checkbox"] {
    accent-color: var(--accent);
    width: 16px;
    height: 16px;
    cursor: pointer;
  }

  .padding-result {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.8rem;
    color: var(--yellow);
    margin-left: auto;
  }

  .empty-state {
    text-align: center;
    padding: 2.5rem;
    color: var(--text-dim);
    font-size: 0.9rem;
  }

  @media (max-width: 700px) {
    .field-row { grid-template-columns: 1fr 1fr; gap: 0.5rem; }
    .column-labels { display: none; }
    .field-row .size-display { text-align: left; }
  }
</style>
