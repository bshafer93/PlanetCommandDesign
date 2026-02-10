# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Dev Commands

```bash
npm run dev          # Runs Vite dev server + Express backend concurrently
npm run build        # svelte-check --tsconfig ./tsconfig.json && vite build
npm run preview      # Preview production build
```

The dev server proxies `/api` requests to `http://localhost:3001` (Express backend).

## Architecture

**Svelte 5 + Vite + TypeScript** game design tools site with tab-based navigation. ES modules throughout (`"type": "module"` in package.json).

### Frontend

- **Hash routing** — `App.svelte` uses `window.location.hash` (#tool-id) for tab navigation, no router library. Components mount/unmount via `{#key activeToolId}`.
- **Tool registration** — Each tool is a Svelte component in `src/tools/<name>/`. Register by importing the component and adding `{ id, label, component }` to the `tools` array in `App.svelte`. The `ToolDef` interface is in `src/types.ts`.
- **Svelte 5 runes** — Use `$state()`, `$derived`, `$effect()`, `bind:value`, `onclick={handler}`, and direct component references (not `svelte:component`).
- **Styling** — Dark theme via CSS custom properties in `src/styles/global.css`. Fonts: "DM Sans" (body), "JetBrains Mono" (headers/code). No CSS framework.
- **Charts** — Chart.js with canvas refs (`bind:this`). Colors are hardcoded hex constants (CSS vars don't work in canvas). Each chart is created in a `$effect()` and destroyed on cleanup.

### Current Tools

- **struct-sizer** (`src/tools/struct-sizer/`) — C++ struct memory/padding estimator.
- **power-gen** (`src/tools/power-gen/`) — Power generator & thruster design. Sub-tabs for Generators (4 charts) and Thrusters (placeholder). Reference data in `data/*.json` (10 files).
- **production-chain** (`src/tools/production-chain/`) — Production chain design for spacecraft construction. Reference data in `data/*.json` (4 files: material-breakdown, raw-resource-requirements, production-constraints, logistics-vehicles). Charts: material doughnut breakdowns, raw resource bars, raw-vs-finished stacked bars, hauls-to-build log-scale comparisons. Two reference ship scales: 30t baseline orbital-class and 100kt carrier.

### Backend

Express server in `server/` on port 3001. Entry: `server/index.ts`, routes in `server/routes/`. JSON file storage in `server/data/` (gitignored). Has its own `tsconfig.json` targeting ES2022/Node.

### Deployment

GitHub Actions (`.github/workflows/deploy.yml`) auto-deploys on push to `main`:
- Frontend built and rsynced to `/var/www/planet-command/` on the DigitalOcean droplet
- Server rsynced to `/opt/planet-command-server/`, managed by PM2 (`planet-command-api`)
- Nginx serves frontend with SPA fallback, reverse-proxies `/api/` to localhost:3001
- Secrets: `DEPLOY_SSH_KEY`, `DEPLOY_HOST`
