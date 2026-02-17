// ── 3D Vector helpers ──────────────────────────────────────────

export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

export const add  = (a: Vec3, b: Vec3): Vec3 => ({ x: a.x + b.x, y: a.y + b.y, z: a.z + b.z });
export const sub  = (a: Vec3, b: Vec3): Vec3 => ({ x: a.x - b.x, y: a.y - b.y, z: a.z - b.z });
export const scale = (v: Vec3, s: number): Vec3 => ({ x: v.x * s, y: v.y * s, z: v.z * s });
export const dot   = (a: Vec3, b: Vec3): number => a.x * b.x + a.y * b.y + a.z * b.z;
export const cross = (a: Vec3, b: Vec3): Vec3 => ({
  x: a.y * b.z - a.z * b.y,
  y: a.z * b.x - a.x * b.z,
  z: a.x * b.y - a.y * b.x,
});
export const mag = (v: Vec3): number => Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);

// ── Stumpff functions ─────────────────────────────────────────

function stumpffC(z: number): number {
  if (Math.abs(z) < 1e-10) return 1 / 2 - z / 24 + (z * z) / 720;
  if (z > 0) return (1 - Math.cos(Math.sqrt(z))) / z;
  const sqnz = Math.sqrt(-z);
  return (1 - Math.cosh(sqnz)) / z;
}

function stumpffS(z: number): number {
  if (Math.abs(z) < 1e-10) return 1 / 6 - z / 120 + (z * z) / 5040;
  if (z > 0) {
    const sq = Math.sqrt(z);
    return (sq - Math.sin(sq)) / (sq * sq * sq);
  }
  const sq = Math.sqrt(-z);
  return (Math.sinh(sq) - sq) / (sq * sq * sq);
}

// ── Lambert solver (universal-variable method) ────────────────
// Reference: Curtis, "Orbital Mechanics for Engineering Students", Algorithm 5.2
//
// Given two position vectors and a time of flight, returns the
// velocity vectors at departure and arrival on the transfer orbit.

export interface LambertResult {
  v1: Vec3;
  v2: Vec3;
}

/** Sun gravitational parameter (km³/s²) */
export const MU_SUN = 1.32712440018e11;

/**
 * Solve Lambert's problem.
 *
 * @param r1Vec  Departure position (km, heliocentric)
 * @param r2Vec  Arrival position   (km, heliocentric)
 * @param dt     Time of flight (seconds, must be > 0)
 * @param mu     Gravitational parameter (km³/s²)
 * @param prograde  true → short-way (Δν < π)
 */
export function solveLambert(
  r1Vec: Vec3,
  r2Vec: Vec3,
  dt: number,
  mu: number = MU_SUN,
  prograde: boolean = true,
): LambertResult | null {
  if (dt <= 0) return null;

  const r1 = mag(r1Vec);
  const r2 = mag(r2Vec);
  if (r1 < 1e-6 || r2 < 1e-6) return null;

  const cosDnu = dot(r1Vec, r2Vec) / (r1 * r2);
  const cz = cross(r1Vec, r2Vec).z;

  // Transfer angle direction
  let sinDnu: number;
  if (prograde) {
    sinDnu = cz >= 0
      ? Math.sqrt(Math.max(0, 1 - cosDnu * cosDnu))
      : -Math.sqrt(Math.max(0, 1 - cosDnu * cosDnu));
  } else {
    sinDnu = cz >= 0
      ? -Math.sqrt(Math.max(0, 1 - cosDnu * cosDnu))
      : Math.sqrt(Math.max(0, 1 - cosDnu * cosDnu));
  }

  const denom = 1 - cosDnu;
  if (Math.abs(denom) < 1e-14) return null; // ~0° or ~360° transfer

  const A = sinDnu * Math.sqrt(r1 * r2 / denom);
  if (Math.abs(A) < 1e-10) return null;

  const sqrtMu = Math.sqrt(mu);

  // ── Newton-Raphson iteration for z ────────────────────────
  let z = 0; // initial guess (parabolic)
  const MAX_ITER = 200;
  const TOL = 1e-10;

  // Helper: evaluate y and F at a given z
  function evalF(zz: number): { y: number; F: number } | null {
    const C = stumpffC(zz);
    const S = stumpffS(zz);
    const sqrtC = Math.sqrt(Math.abs(C));
    if (sqrtC < 1e-30) return null;
    const y = r1 + r2 + A * (zz * S - 1) / sqrtC;
    if (y < 0) return null;
    const chi = Math.sqrt(y / C);
    const F = chi * chi * chi * S + A * Math.sqrt(y) - sqrtMu * dt;
    return { y, F };
  }

  let converged = false;
  for (let i = 0; i < MAX_ITER; i++) {
    const ev = evalF(z);
    if (!ev) { z += 0.5; continue; }

    // Numerical derivative (central difference)
    const h = 1e-7 * (1 + Math.abs(z));
    const evP = evalF(z + h);
    const evM = evalF(z - h);
    if (!evP || !evM) { z += 0.5; continue; }

    const dF = (evP.F - evM.F) / (2 * h);
    if (Math.abs(dF) < 1e-30) { z += 0.1; continue; }

    const zNew = z - ev.F / dF;
    if (Math.abs(zNew - z) < TOL) {
      z = zNew;
      converged = true;
      break;
    }
    z = zNew;
  }

  if (!converged) return null;

  // ── Compute transfer velocities via Lagrange coefficients ──
  const C = stumpffC(z);
  const S = stumpffS(z);
  const sqrtC = Math.sqrt(Math.abs(C));
  const y = r1 + r2 + A * (z * S - 1) / sqrtC;
  if (y < 0) return null;

  const f    = 1 - y / r1;
  const gDot = 1 - y / r2;
  const g    = A * Math.sqrt(y / mu);
  if (Math.abs(g) < 1e-30) return null;

  const v1 = scale(sub(r2Vec, scale(r1Vec, f)), 1 / g);
  const v2 = scale(sub(scale(r2Vec, gDot), r1Vec), 1 / g);

  // Sanity: reject if velocities are unreasonably large (> 200 km/s)
  if (mag(v1) > 200 || mag(v2) > 200) return null;

  return { v1, v2 };
}
