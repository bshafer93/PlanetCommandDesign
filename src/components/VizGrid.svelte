<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    /** Unique group name for this grid (used to isolate drag state) */
    group: string;
    /** Number of panels in this grid */
    count: number;
    /** Panel titles (length must match count) */
    titles: string[];
    /** Render each panel's content by index */
    panel: Snippet<[number]>;
    /** Optional: columns override (default 3) */
    columns?: number;
  }

  let { group, count, titles, panel, columns = 3 }: Props = $props();

  // ── Ordering state ─────────────────────────────────────────
  let ids = $derived(Array.from({ length: count }, (_, i) => i));
  let order: number[] = $state(Array.from({ length: count }, (_, i) => i)); // eslint-disable-line

  let dragSource: number | null = null;
  let dragOverId: number | null = $state(null);

  function onDragStart(e: DragEvent, id: number) {
    dragSource = id;
    e.dataTransfer!.effectAllowed = 'move';
    e.dataTransfer!.setData('text/plain', '');
    (e.target as HTMLElement).closest('.viz-toggle')!.classList.add('viz-dragging');
  }

  function onDragEnd(e: DragEvent) {
    (e.target as HTMLElement).closest('.viz-toggle')?.classList.remove('viz-dragging');
    dragSource = null;
    dragOverId = null;
  }

  function onDragOver(e: DragEvent, id: number) {
    if (dragSource === null || dragSource === id) return;
    e.preventDefault();
    e.dataTransfer!.dropEffect = 'move';
    dragOverId = id;
  }

  function onDragLeave() {
    dragOverId = null;
  }

  function onDrop(e: DragEvent, targetId: number) {
    e.preventDefault();
    if (dragSource === null || dragSource === targetId) return;

    const next = [...order];
    const fromIdx = next.indexOf(dragSource);
    const toIdx = next.indexOf(targetId);
    next.splice(fromIdx, 1);
    next.splice(toIdx, 0, dragSource);
    order = next;

    dragSource = null;
    dragOverId = null;
  }
</script>

<div class="viz-grid" style="grid-template-columns: repeat({columns}, 1fr);">
  {#each ids as id (id)}
    <details
      class="viz-toggle"
      class:viz-drag-over={dragOverId === id}
      open
      draggable="true"
      style="order: {order.indexOf(id)}"
      ondragstart={(e) => onDragStart(e, id)}
      ondragend={onDragEnd}
      ondragover={(e) => onDragOver(e, id)}
      ondragleave={onDragLeave}
      ondrop={(e) => onDrop(e, id)}
    >
      <summary><span class="drag-handle">⋮⋮</span> {titles[id]}</summary>
      {@render panel(id)}
    </details>
  {/each}
</div>

<style>
  .viz-grid {
    display: grid;
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

  .viz-toggle > summary::-webkit-details-marker {
    display: none;
  }

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

  @media (max-width: 1200px) {
    .viz-grid {
      grid-template-columns: repeat(2, 1fr) !important;
    }
  }

  @media (max-width: 800px) {
    .viz-grid {
      grid-template-columns: 1fr !important;
    }
  }
</style>
