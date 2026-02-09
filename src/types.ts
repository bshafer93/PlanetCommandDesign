import type { Component } from 'svelte';

export interface ToolDef {
  id: string;
  label: string;
  component: Component;
}
