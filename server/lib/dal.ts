import pg from 'pg';

const { Pool } = pg;

// ── Connection pool ────────────────────────────────────────────────
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

pool.on('error', (err) => {
  console.error('Unexpected pool error:', err);
});

// ── Types ──────────────────────────────────────────────────────────

export interface Material {
  id: number;
  name: string;
  category: string;
  density_kgm3: number;
  specific_heat_jkgk: number | null;
  thermal_conductivity_wmk: number | null;
  electrical_conductivity_sm: number | null;
  yield_strength_mpa: number | null;
  ultimate_tensile_strength_mpa: number | null;
  melting_point_k: number | null;
  boiling_point_k: number | null;
  latent_heat_fusion_jkg: number | null;
  notes: string | null;
}

export interface Element {
  id: number;
  atomic_number: number;
  symbol: string;
  name: string;
  atomic_mass: number | null;
  category: string | null;
  appearance: string | null;
  phase: string | null;
  block: string | null;
  period: number | null;
  group: number | null;
  density: number | null;
  melting_point_k: number | null;
  boiling_point_k: number | null;
  molar_heat: number | null;
  electron_configuration: string | null;
  electron_configuration_semantic: string | null;
  electron_affinity: number | null;
  electronegativity_pauling: number | null;
  ionization_energies: number[] | null;
  shells: number[] | null;
  discovered_by: string | null;
  named_by: string | null;
  summary: string | null;
  source_url: string | null;
  cpk_hex: string | null;
  spectral_img: string | null;
  bohr_model_image: string | null;
  bohr_model_3d: string | null;
  image_url: string | null;
  image_title: string | null;
  image_attribution: string | null;
  xpos: number | null;
  ypos: number | null;
  wxpos: number | null;
  wypos: number | null;
}

// ── Materials queries ──────────────────────────────────────────────

export async function getAllMaterials(): Promise<Material[]> {
  const { rows } = await pool.query<Material>(
    'SELECT * FROM materials ORDER BY name'
  );
  return rows;
}

export async function getMaterialById(id: number): Promise<Material | null> {
  const { rows } = await pool.query<Material>(
    'SELECT * FROM materials WHERE id = $1',
    [id]
  );
  return rows[0] ?? null;
}

export async function getMaterialsByCategory(category: string): Promise<Material[]> {
  const { rows } = await pool.query<Material>(
    'SELECT * FROM materials WHERE category = $1 ORDER BY name',
    [category]
  );
  return rows;
}

export async function searchMaterials(term: string): Promise<Material[]> {
  const { rows } = await pool.query<Material>(
    'SELECT * FROM materials WHERE name ILIKE $1 ORDER BY name',
    [`%${term}%`]
  );
  return rows;
}

// ── Elements queries ───────────────────────────────────────────────

export async function getAllElements(): Promise<Element[]> {
  const { rows } = await pool.query<Element>(
    'SELECT * FROM periodic_elements ORDER BY atomic_number'
  );
  return rows;
}

export async function getElementById(atomicNumber: number): Promise<Element | null> {
  const { rows } = await pool.query<Element>(
    'SELECT * FROM periodic_elements WHERE atomic_number = $1',
    [atomicNumber]
  );
  return rows[0] ?? null;
}

export async function getElementsByCategory(category: string): Promise<Element[]> {
  const { rows } = await pool.query<Element>(
    'SELECT * FROM periodic_elements WHERE category = $1 ORDER BY atomic_number',
    [category]
  );
  return rows;
}

export async function searchElements(term: string): Promise<Element[]> {
  const { rows } = await pool.query<Element>(
    'SELECT * FROM periodic_elements WHERE name ILIKE $1 OR symbol ILIKE $1 ORDER BY atomic_number',
    [`%${term}%`]
  );
  return rows;
}

// ── Raw query (escape hatch) ───────────────────────────────────────

export async function query<T extends pg.QueryResultRow = any>(
  text: string,
  params?: any[]
): Promise<pg.QueryResult<T>> {
  return pool.query<T>(text, params);
}

// ── Lifecycle ──────────────────────────────────────────────────────

export async function closePool(): Promise<void> {
  await pool.end();
}
