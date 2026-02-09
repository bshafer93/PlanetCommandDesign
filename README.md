# PlanetCommandDesign

Game design tools and calculators for Planet Command.

**Live site:** [https://bshafer93.github.io/PlanetCommandDesign/](https://bshafer93.github.io/PlanetCommandDesign/)

## Tools

- **struct_sizer** - Estimate memory footprint of a C++ struct or class with alignment padding visualization

## Development

```bash
npm install      # Install dependencies
npm run dev      # Start dev server
npm run build    # Type-check + production build
npm run preview  # Preview production build locally
npm run deploy   # Build and deploy to GitHub Pages
```

## Adding a New Tool

1. Create a Svelte component at `src/tools/your-tool/YourTool.svelte`
2. Register it in `src/App.svelte`:
   ```ts
   import YourTool from './tools/your-tool/YourTool.svelte';

   const tools: ToolDef[] = [
     // ...existing tools
     { id: 'your-tool', label: 'your_tool', component: YourTool },
   ];
   ```

The tool will automatically get a tab in the navigation bar and hash routing (`#your-tool`).
