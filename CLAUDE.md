# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Planet Command Design** is a game design tools & calculators site for the "Planet Command" universe. It provides interactive tools for spacecraft engineering: struct memory sizing, power generation design, production chain logistics, and physics calculations (projectiles, lasers, particle beams).

## Build & Dev Commands

```bash
npm run dev          # Runs Vite dev server + Express backend concurrently
npm run dev:client   # Vite dev server only
npm run dev:server   # Express backend only (tsx watch)
npm run build        # svelte-check && vite build
npm run preview      # Preview production build
```

The dev server proxies `/api` requests to `http://localhost:3001` (Express backend).

There is no test runner or linter configured. `npm run build` runs `svelte-check` for type-checking before the Vite build.

## Directory Structure

```
├── .github/workflows/deploy.yml   # CI/CD: auto-deploy on push to main
├── server/                         # Express backend (port 3001)
│   ├── index.ts                    # Entry point, CORS, JSON middleware
│   ├── routes/save.ts              # POST /api/save — JSON file persistence
│   ├── tsconfig.json               # Backend TS config (ES2022, Node)
│   └── data/                       # Runtime JSON storage (gitignored)
├── src/
│   ├── main.ts                     # Svelte app mount point
│   ├── App.svelte                  # Root layout, tab bar, hash routing
│   ├── types.ts                    # ToolDef interface
│   ├── styles/global.css           # Dark theme CSS custom properties
│   ├── components/
│   │   └── SliderInput.svelte      # Reusable slider+number input (linear/log)
│   └── tools/
│       ├── struct-sizer/           # C++ struct memory calculator
│       ├── power-gen/              # Power generation & thruster design
│       ├── production-chain/       # Spacecraft construction logistics
│       └── calculations/           # Physics calculators (projectile/laser/particle beam)
├── index.html                      # HTML entry point
├── package.json                    # ES module, scripts, deps
├── tsconfig.json                   # Frontend TS config (ES2020, DOM)
├── vite.config.ts                  # Vite + Svelte plugin, /api proxy
└── svelte.config.js                # Svelte preprocessor config
```

## Architecture

**Svelte 5 + Vite + TypeScript** game design tools site with tab-based navigation. ES modules throughout (`"type": "module"` in package.json).

### Frontend

- **Hash routing** — `App.svelte` uses `window.location.hash` (#tool-id) for tab navigation, no router library. Components mount/unmount via `{#key activeToolId}`.
- **Tool registration** — Each tool is a Svelte component in `src/tools/<name>/`. Register by importing the component and adding `{ id, label, component }` to the `tools` array in `App.svelte`. The `ToolDef` interface is in `src/types.ts`.
- **Svelte 5 runes** — Use `$state()`, `$derived()`, `$derived.by()`, `$effect()`, `$props()`, `$bindable()`, `bind:value`, `onclick={handler}`, and direct component references (not `svelte:component`).
- **Styling** — Dark theme via CSS custom properties in `src/styles/global.css`. Fonts: "DM Sans" (body), "JetBrains Mono" (headers/code). No CSS framework. Scoped `<style>` blocks in each component.
- **Charts** — Chart.js v4 with canvas refs (`bind:this`). Colors are hardcoded hex constants (CSS vars don't work in canvas). Each chart is created in a `$effect()` and destroyed on cleanup. Raw canvas 2D API used for heatmaps (e.g., range-vs-power in laser calculator, particle beam heatmap).
- **Reusable components** — Shared UI components live in `src/components/`. Use `SliderInput` for any slider+number input combo (supports linear and `log` mode for large ranges, with optional `inputMax` override).

### Adding a New Tool

1. Create `src/tools/<tool-id>/ToolName.svelte`
2. Optionally add a `data/` subdirectory for JSON reference data
3. Import the component in `App.svelte`
4. Add `{ id: '<tool-id>', label: '<tab_label>', component: ToolName }` to the `tools` array
5. The tool is now routable at `#<tool-id>`

### Current Tools

- **struct-sizer** (`src/tools/struct-sizer/`) — C++ struct memory/padding estimator. Supports 51 types (primitives, STL containers, pointers). No external data files.
- **power-gen** (`src/tools/power-gen/`) — Power generator & thruster design. Sub-tabs for Generators (4 charts) and Thrusters (placeholder). Reference data in `data/*.json` (10 files: generator-comparison, fuel-energy-density, radiator-cooling, radiator-materials, carrier-power-bounds, nuclear-conversion-chain, water-use-nuclear, direct-conversion-methods, fusion-size-factors, fusion-tech-improvements).
- **production-chain** (`src/tools/production-chain/`) — Production chain design for spacecraft construction. Reference data in `data/*.json` (4 files: material-breakdown, raw-resource-requirements, production-constraints, logistics-vehicles). Charts: material doughnut breakdowns, raw resource bars, raw-vs-finished stacked bars, hauls-to-build log-scale comparisons. Two reference ship scales: 30t baseline orbital-class and 100kt carrier.
- **calculations** (`src/tools/calculations/`) — Physics calculators with sub-tabs: Projectile (KE = ½mv², shape/material selectors), Laser (steel penetration via energy-balance melt-through model with slider inputs, penetration bar, time-vs-depth chart, range-vs-power heatmap), and Particle Beam (charged/neutral/laser feasibility at multiple ranges, comparison heatmaps with blacked-out ineffective regions). Particle beam data in `data/*.json` (5 files: particle-beam-feasibility, particle-beam-comparison, particle-beam-divergence, particle-beam-efficiencies, particle-beam-target).

### CSS Custom Properties

Defined in `src/styles/global.css` on `:root`:

| Variable        | Value                          | Usage          |
|-----------------|--------------------------------|----------------|
| `--bg`          | `#0e1117`                      | Page background |
| `--surface`     | `#161b22`                      | Card/panel bg  |
| `--surface2`    | `#1c2231`                      | Nested panel bg |
| `--border`      | `#2a3142`                      | Borders        |
| `--text`        | `#e2e8f0`                      | Primary text   |
| `--text-dim`    | `#8492a6`                      | Secondary text |
| `--accent`      | `#60a5fa`                      | Blue accent    |
| `--accent-glow` | `rgba(96, 165, 250, 0.15)`    | Glow effects   |
| `--red`         | `#f87171`                      | Red            |
| `--green`       | `#4ade80`                      | Green          |
| `--yellow`      | `#fbbf24`                      | Yellow         |
| `--purple`      | `#c084fc`                      | Purple         |
| `--orange`      | `#fb923c`                      | Orange         |
| `--pink`        | `#f472b6`                      | Pink           |
| `--cyan`        | `#22d3ee`                      | Cyan           |
| `--teal`        | `#2dd4bf`                      | Teal           |

**Note:** CSS custom properties cannot be used inside `<canvas>` elements. Use hardcoded hex values matching the above when drawing on Chart.js or 2D canvas.

### Backend

Express server in `server/` on port 3001. Entry: `server/index.ts`, routes in `server/routes/`. JSON file storage in `server/data/` (gitignored). Has its own `tsconfig.json` targeting ES2022/Node.

Single endpoint:
- `POST /api/save` — accepts `{ filename: string, data: any }`, sanitizes filename (alphanumeric/dash/underscore only), writes JSON to `server/data/`.

### Data File Conventions

Tool-specific reference data lives in `src/tools/<name>/data/*.json`. These are static JSON files imported at build time. Common patterns:
- Top-level `title` and `description` fields for documentation
- Arrays of objects with numeric properties for chart data
- Named keys for lookup tables (e.g., materials, technologies)

### Deployment

GitHub Actions (`.github/workflows/deploy.yml`) auto-deploys on push to `main`:
- Builds with Node 20 (`npm ci && npm run build`)
- Frontend rsynced to `/var/www/planet-command/` on the DigitalOcean droplet
- Server rsynced to `/opt/planet-command-server/`, managed by PM2 (`planet-command-api`)
- Nginx serves frontend with SPA fallback, reverse-proxies `/api/` to localhost:3001
- Secrets: `DEPLOY_SSH_KEY`, `DEPLOY_HOST`

### Key Dependencies

| Package    | Version  | Purpose                                |
|------------|----------|----------------------------------------|
| svelte     | ^5.0.0   | UI framework (runes API)               |
| vite       | ^6.1.0   | Bundler and dev server                 |
| chart.js   | ^4.5.1   | Charts (bar, doughnut, line, scatter)  |
| express    | ^4.21.0  | Backend API server                     |
| typescript | ^5.7.0   | Type checking                          |
| tsx        | ^4.19.0  | TypeScript execution for backend       |
