// ── JPL Horizons API client ───────────────────────────────────
// Fetches heliocentric state vectors (position + velocity) for
// solar-system bodies. Returns positions in km and velocities in km/s.

import type { Vec3 } from './lambert.js';

const HORIZONS_API = 'https://ssd.jpl.nasa.gov/api/horizons.api';

/** Horizons body IDs for the major planets */
export const PLANET_IDS: Record<string, string> = {
  mercury: '199',
  venus:   '299',
  earth:   '399',
  mars:    '499',
  jupiter: '599',
  saturn:  '699',
  uranus:  '799',
  neptune: '899',
};

export interface StateVector {
  jd: number;        // Julian date (TDB)
  date: string;      // Calendar date string
  position: Vec3;    // km, heliocentric ecliptic
  velocity: Vec3;    // km/s
}

/**
 * Fetch heliocentric state vectors from JPL Horizons.
 *
 * @param bodyId    Horizons COMMAND id (e.g. '399' for Earth)
 * @param startDate ISO-ish date string (e.g. '2025-06-01')
 * @param endDate   ISO-ish date string
 * @param steps     Number of uniform time-steps (Horizons returns steps+1 points)
 */
export async function getEphemeris(
  bodyId: string,
  startDate: string,
  endDate: string,
  steps: number,
): Promise<StateVector[]> {
  // Build URL with single-quoted parameter values (Horizons convention)
  const params = [
    `format=json`,
    `COMMAND='${bodyId}'`,
    `OBJ_DATA='NO'`,
    `MAKE_EPHEM='YES'`,
    `EPHEM_TYPE='VECTORS'`,
    `CENTER='500@10'`,             // Sun centre
    `START_TIME='${startDate}'`,
    `STOP_TIME='${endDate}'`,
    `STEP_SIZE='${steps}'`,        // unitless integer → uniform steps
    `VEC_TABLE='2'`,               // position + velocity only
    `CSV_FORMAT='YES'`,
    `VEC_LABELS='NO'`,
  ].join('&');

  const url = `${HORIZONS_API}?${params}`;

  const res = await fetch(url);
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Horizons HTTP ${res.status}: ${body.slice(0, 200)}`);
  }

  const json = (await res.json()) as { result?: string; [k: string]: unknown };
  if (!json.result || typeof json.result !== 'string') {
    throw new Error('Horizons response missing "result" field');
  }

  return parseEphemeris(json.result);
}

/** Parse the text block between $$SOE … $$EOE into state vectors. */
function parseEphemeris(result: string): StateVector[] {
  const lines = result.split('\n');
  const soe = lines.findIndex(l => l.trim() === '$$SOE');
  const eoe = lines.findIndex(l => l.trim() === '$$EOE');
  if (soe < 0 || eoe < 0) {
    throw new Error('Could not find $$SOE/$$EOE markers in Horizons response');
  }

  const states: StateVector[] = [];

  for (let i = soe + 1; i < eoe; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    // CSV columns: JDTDB, CalDate, X, Y, Z, VX, VY, VZ, ...
    const cols = line.split(',').map(s => s.trim());
    if (cols.length < 8) continue;

    const jd = parseFloat(cols[0]);
    if (isNaN(jd)) continue;

    // Horizons vectors default to KM-S for the API
    states.push({
      jd,
      date: cols[1].replace(/^ *A\.D\. */, '').trim(),
      position: {
        x: parseFloat(cols[2]),
        y: parseFloat(cols[3]),
        z: parseFloat(cols[4]),
      },
      velocity: {
        x: parseFloat(cols[5]),
        y: parseFloat(cols[6]),
        z: parseFloat(cols[7]),
      },
    });
  }

  if (states.length === 0) {
    throw new Error('Horizons returned no data points');
  }

  return states;
}
