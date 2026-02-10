<script lang="ts">
  interface Props {
    label: string;
    value: number;
    min: number;
    max: number;
    step?: number;
    log?: boolean;
    inputMax?: number;
  }

  let { label, value = $bindable(), min, max, step = 1, log = false, inputMax }: Props = $props();

  let numMax = $derived(inputMax ?? max);

  function valueToSlider(v: number): number {
    const logMin = Math.log10(Math.max(min, 1e-10));
    const logMax = Math.log10(Math.max(max, 1e-10));
    return ((Math.log10(Math.max(v, min)) - logMin) / (logMax - logMin)) * 1000;
  }

  function sliderToValue(pos: number): number {
    const logMin = Math.log10(Math.max(min, 1e-10));
    const logMax = Math.log10(Math.max(max, 1e-10));
    return +Math.pow(10, logMin + (pos / 1000) * (logMax - logMin)).toPrecision(3);
  }
</script>

<div class="field-group">
  <label class="field-label">{label}</label>
  <div class="slider-row">
    {#if log}
      <input type="range" min="0" max="1000" step="1"
        value={valueToSlider(value)}
        oninput={(e) => value = sliderToValue(+(e.target as HTMLInputElement).value)}
        class="slider-range" />
    {:else}
      <input type="range" {min} {max} {step} bind:value class="slider-range" />
    {/if}
    <input type="number" bind:value min={min} max={numMax} {step} class="slider-num" />
  </div>
</div>

<style>
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

  .slider-row {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    min-width: 0;
    overflow: hidden;
  }

  .slider-range {
    flex: 1;
    min-width: 0;
    accent-color: var(--accent);
    height: 6px;
  }

  input.slider-num {
    width: 80px;
    flex-shrink: 0;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.85rem;
    padding: 0.45rem 0.6rem;
    outline: none;
    transition: border-color 0.15s;
  }

  input.slider-num:focus {
    border-color: var(--accent);
  }
</style>
