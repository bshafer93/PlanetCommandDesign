<script lang="ts">
  import type { ToolDef } from './types';
  import StructSizer from './tools/struct-sizer/StructSizer.svelte';
  import PowerGen from './tools/power-gen/PowerGen.svelte';
  import ProductionChain from './tools/production-chain/ProductionChain.svelte';

  const tools: ToolDef[] = [
    { id: 'struct-sizer', label: 'struct_sizer', component: StructSizer },
    { id: 'power-gen', label: 'power_gen', component: PowerGen },
    { id: 'production-chain', label: 'production_chain', component: ProductionChain },
  ];

  let activeToolId = $state(getInitialTab());

  function getInitialTab(): string {
    const hash = window.location.hash.replace('#', '');
    return tools.find(t => t.id === hash)?.id ?? tools[0].id;
  }

  let ActiveComponent = $derived((tools.find(t => t.id === activeToolId) ?? tools[0]).component);

  function switchTab(id: string) {
    activeToolId = id;
    history.replaceState(null, '', `#${id}`);
  }

  $effect(() => {
    function onHashChange() {
      const hash = window.location.hash.replace('#', '');
      const found = tools.find(t => t.id === hash);
      if (found) activeToolId = found.id;
    }
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  });
</script>

<header>
  <h1>Planet Command Design</h1>
  <p>Game design tools & calculators</p>
</header>

<nav class="tab-bar">
  {#each tools as tool}
    <button
      class="tab-btn"
      class:active={tool.id === activeToolId}
      onclick={() => switchTab(tool.id)}
    >
      {tool.label}
    </button>
  {/each}
</nav>

<main>
  {#key activeToolId}
    <ActiveComponent />
  {/key}
</main>

<style>
  .tab-bar {
    display: flex;
    gap: 0;
    border-bottom: 1px solid var(--border);
    margin-bottom: 2rem;
  }

  .tab-btn {
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    color: var(--text-dim);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.85rem;
    font-weight: 500;
    padding: 0.6rem 1.25rem;
    cursor: pointer;
    transition: color 0.2s, border-color 0.2s;
  }

  .tab-btn:hover {
    color: var(--text);
  }

  .tab-btn.active {
    color: var(--accent);
    border-bottom-color: var(--accent);
  }
</style>
