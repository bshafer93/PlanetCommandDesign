// ── Orbit-planning routes ─────────────────────────────────────
// POST /api/orbit/porkchop  — compute a porkchop plot grid
// GET  /api/orbit/planets    — list available planet names

import { Router, type Request, type Response } from 'express';
import { getEphemeris, PLANET_IDS, type StateVector } from '../lib/horizons.js';
import { solveLambert, sub, mag, MU_SUN } from '../lib/lambert.js';

export const orbitRouter = Router();

// ── Ephemeris cache ─────────────────────────────────────────
// Key: "bodyId|startDate|endDate|steps"  →  { data, timestamp }
const CACHE_TTL_MS = 30 * 60 * 1000; // 30 minutes
const ephemerisCache = new Map<string, { data: StateVector[]; ts: number }>();

function cacheKey(bodyId: string, start: string, end: string, steps: number) {
  return `${bodyId}|${start}|${end}|${steps}`;
}

async function getCachedEphemeris(
  bodyId: string, start: string, end: string, steps: number,
): Promise<StateVector[]> {
  const key = cacheKey(bodyId, start, end, steps);
  const cached = ephemerisCache.get(key);
  if (cached && Date.now() - cached.ts < CACHE_TTL_MS) {
    return cached.data;
  }
  const data = await getEphemeris(bodyId, start, end, steps);
  ephemerisCache.set(key, { data, ts: Date.now() });
  return data;
}

// ── Planet list ──────────────────────────────────────────────
orbitRouter.get('/orbit/planets', (_req: Request, res: Response) => {
  res.json({
    planets: Object.keys(PLANET_IDS),
  });
});

// ── Porkchop plot ────────────────────────────────────────────
interface PorkchopBody {
  departurePlanet: string;
  arrivalPlanet: string;
  departureStart: string;   // e.g. '2025-06-01'
  departureEnd: string;
  arrivalStart: string;
  arrivalEnd: string;
  steps?: number;           // grid resolution per axis (default 40)
}

orbitRouter.post('/orbit/porkchop', async (req: Request, res: Response) => {
  const {
    departurePlanet,
    arrivalPlanet,
    departureStart,
    departureEnd,
    arrivalStart,
    arrivalEnd,
    steps = 40,
  } = req.body as PorkchopBody;

  // ── Validate inputs ────────────────────────────────────────
  const depId = PLANET_IDS[departurePlanet?.toLowerCase()];
  const arrId = PLANET_IDS[arrivalPlanet?.toLowerCase()];

  if (!depId || !arrId) {
    res.status(400).json({
      error: `Invalid planet. Available: ${Object.keys(PLANET_IDS).join(', ')}`,
    });
    return;
  }

  if (!departureStart || !departureEnd || !arrivalStart || !arrivalEnd) {
    res.status(400).json({ error: 'Missing date range fields' });
    return;
  }

  const gridSteps = Math.min(Math.max(Math.round(steps), 5), 100);

  try {
    // ── Fetch ephemeris for both planets in parallel ──────────
    const [depStates, arrStates] = await Promise.all([
      getCachedEphemeris(depId, departureStart, departureEnd, gridSteps),
      getCachedEphemeris(arrId, arrivalStart, arrivalEnd, gridSteps),
    ]);

    // ── Build the porkchop grid ──────────────────────────────
    // Rows = departure dates, Columns = arrival dates
    const c3Grid:       number[][] = [];
    const arrVinfGrid:  number[][] = [];
    const totalDvGrid:  number[][] = [];
    const tofGrid:      number[][] = [];

    for (let i = 0; i < depStates.length; i++) {
      const c3Row:      number[] = [];
      const arrVRow:    number[] = [];
      const dvRow:      number[] = [];
      const tofRow:     number[] = [];

      for (let j = 0; j < arrStates.length; j++) {
        const dt_s = (arrStates[j].jd - depStates[i].jd) * 86_400; // seconds

        if (dt_s <= 0) {
          c3Row.push(NaN);
          arrVRow.push(NaN);
          dvRow.push(NaN);
          tofRow.push(NaN);
          continue;
        }

        const result = solveLambert(
          depStates[i].position,
          arrStates[j].position,
          dt_s,
          MU_SUN,
          true,
        );

        if (!result) {
          c3Row.push(NaN);
          arrVRow.push(NaN);
          dvRow.push(NaN);
          tofRow.push(NaN);
          continue;
        }

        const depVinf = mag(sub(result.v1, depStates[i].velocity));
        const arrVinf = mag(sub(result.v2, arrStates[j].velocity));

        c3Row.push(depVinf * depVinf);       // km²/s²
        arrVRow.push(arrVinf);                // km/s
        dvRow.push(depVinf + arrVinf);        // km/s  (simple sum)
        tofRow.push(dt_s / 86_400);           // days
      }

      c3Grid.push(c3Row);
      arrVinfGrid.push(arrVRow);
      totalDvGrid.push(dvRow);
      tofGrid.push(tofRow);
    }

    res.json({
      departurePlanet: departurePlanet.toLowerCase(),
      arrivalPlanet: arrivalPlanet.toLowerCase(),
      departureDates: depStates.map(s => s.date),
      arrivalDates:   arrStates.map(s => s.date),
      departureJDs:   depStates.map(s => s.jd),
      arrivalJDs:     arrStates.map(s => s.jd),
      grid: {
        c3_km2s2:          c3Grid,
        arrivalVinf_kms:   arrVinfGrid,
        totalDeltaV_kms:   totalDvGrid,
        tof_days:          tofGrid,
      },
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Internal server error';
    console.error('Porkchop error:', message);
    res.status(500).json({ error: message });
  }
});
