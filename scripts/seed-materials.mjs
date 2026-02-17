import pg from 'pg';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const jsonPath = join(__dirname, '..', 'src', 'tools', 'calculations', 'data', 'materials-database.json');
const db = JSON.parse(readFileSync(jsonPath, 'utf-8'));

const CONNECTION = 'postgresql://planetcommand:planetcommand_db_pass@192.168.100.52:5432/PlanetCommandDesignDB';

const client = new pg.Client({ connectionString: CONNECTION });

async function main() {
  await client.connect();
  console.log('Connected to PlanetCommandDesignDB');

  // Create table
  await client.query(`
    CREATE TABLE IF NOT EXISTS materials (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) NOT NULL UNIQUE,
      category VARCHAR(20) NOT NULL,
      density_kgm3 DOUBLE PRECISION NOT NULL,
      specific_heat_jkgk DOUBLE PRECISION,
      thermal_conductivity_wmk DOUBLE PRECISION,
      electrical_conductivity_sm DOUBLE PRECISION,
      yield_strength_mpa DOUBLE PRECISION,
      ultimate_tensile_strength_mpa DOUBLE PRECISION,
      melting_point_k DOUBLE PRECISION,
      boiling_point_k DOUBLE PRECISION,
      latent_heat_fusion_jkg DOUBLE PRECISION,
      notes TEXT
    );
  `);
  console.log('Table "materials" created (or already exists)');

  // Insert materials
  const insertSQL = `
    INSERT INTO materials (
      name, category, density_kgm3, specific_heat_jkgk,
      thermal_conductivity_wmk, electrical_conductivity_sm,
      yield_strength_mpa, ultimate_tensile_strength_mpa,
      melting_point_k, boiling_point_k, latent_heat_fusion_jkg, notes
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
    ON CONFLICT (name) DO UPDATE SET
      category = EXCLUDED.category,
      density_kgm3 = EXCLUDED.density_kgm3,
      specific_heat_jkgk = EXCLUDED.specific_heat_jkgk,
      thermal_conductivity_wmk = EXCLUDED.thermal_conductivity_wmk,
      electrical_conductivity_sm = EXCLUDED.electrical_conductivity_sm,
      yield_strength_mpa = EXCLUDED.yield_strength_mpa,
      ultimate_tensile_strength_mpa = EXCLUDED.ultimate_tensile_strength_mpa,
      melting_point_k = EXCLUDED.melting_point_k,
      boiling_point_k = EXCLUDED.boiling_point_k,
      latent_heat_fusion_jkg = EXCLUDED.latent_heat_fusion_jkg,
      notes = EXCLUDED.notes;
  `;

  let inserted = 0;
  for (const m of db.materials) {
    await client.query(insertSQL, [
      m.name,
      m.category,
      m.density_kgm3,
      m.specificHeat_JkgK ?? null,
      m.thermalConductivity_WmK ?? null,
      m.electricalConductivity_Sm ?? null,
      m.yieldStrength_MPa ?? null,
      m.ultimateTensileStrength_MPa ?? null,
      m.meltingPoint_K ?? null,
      m.boilingPoint_K ?? null,
      m.latentHeatFusion_Jkg ?? null,
      m.notes ?? null,
    ]);
    inserted++;
  }

  console.log(`Inserted/updated ${inserted} materials`);

  // Verify
  const { rows } = await client.query('SELECT count(*) AS total FROM materials');
  console.log(`Total rows in materials table: ${rows[0].total}`);

  const sample = await client.query('SELECT id, name, category, density_kgm3 FROM materials ORDER BY id LIMIT 5');
  console.log('Sample rows:');
  console.table(sample.rows);

  await client.end();
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
