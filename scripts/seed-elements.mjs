import pg from 'pg';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const jsonPath = join(__dirname, 'PeriodicTableJSON.json');
const db = JSON.parse(readFileSync(jsonPath, 'utf-8'));

const CONNECTION = 'postgresql://planetcommand:planetcommand_db_pass@192.168.100.52:5432/PlanetCommandDesignDB';

const client = new pg.Client({ connectionString: CONNECTION });

async function main() {
  await client.connect();
  console.log('Connected to PlanetCommandDesignDB');

  await client.query(`
    CREATE TABLE IF NOT EXISTS periodic_elements (
      id SERIAL PRIMARY KEY,
      atomic_number INT NOT NULL UNIQUE,
      symbol VARCHAR(3) NOT NULL UNIQUE,
      name VARCHAR(50) NOT NULL UNIQUE,
      atomic_mass DOUBLE PRECISION,
      category VARCHAR(60),
      appearance TEXT,
      phase VARCHAR(20),
      block VARCHAR(2),
      period INT,
      "group" INT,
      density DOUBLE PRECISION,
      melting_point_k DOUBLE PRECISION,
      boiling_point_k DOUBLE PRECISION,
      molar_heat DOUBLE PRECISION,
      electron_configuration TEXT,
      electron_configuration_semantic TEXT,
      electron_affinity DOUBLE PRECISION,
      electronegativity_pauling DOUBLE PRECISION,
      ionization_energies DOUBLE PRECISION[],
      shells INT[],
      discovered_by VARCHAR(200),
      named_by VARCHAR(200),
      summary TEXT,
      source_url TEXT,
      cpk_hex VARCHAR(6),
      spectral_img TEXT,
      bohr_model_image TEXT,
      bohr_model_3d TEXT,
      image_url TEXT,
      image_title TEXT,
      image_attribution TEXT,
      xpos INT,
      ypos INT,
      wxpos INT,
      wypos INT
    );
  `);
  console.log('Table "periodic_elements" created (or already exists)');

  const insertSQL = `
    INSERT INTO periodic_elements (
      atomic_number, symbol, name, atomic_mass, category, appearance, phase,
      block, period, "group", density, melting_point_k, boiling_point_k,
      molar_heat, electron_configuration, electron_configuration_semantic,
      electron_affinity, electronegativity_pauling, ionization_energies, shells,
      discovered_by, named_by, summary, source_url, cpk_hex,
      spectral_img, bohr_model_image, bohr_model_3d,
      image_url, image_title, image_attribution,
      xpos, ypos, wxpos, wypos
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
      $21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33,$34,$35
    )
    ON CONFLICT (atomic_number) DO UPDATE SET
      symbol = EXCLUDED.symbol,
      name = EXCLUDED.name,
      atomic_mass = EXCLUDED.atomic_mass,
      category = EXCLUDED.category,
      appearance = EXCLUDED.appearance,
      phase = EXCLUDED.phase,
      block = EXCLUDED.block,
      period = EXCLUDED.period,
      "group" = EXCLUDED."group",
      density = EXCLUDED.density,
      melting_point_k = EXCLUDED.melting_point_k,
      boiling_point_k = EXCLUDED.boiling_point_k,
      molar_heat = EXCLUDED.molar_heat,
      electron_configuration = EXCLUDED.electron_configuration,
      electron_configuration_semantic = EXCLUDED.electron_configuration_semantic,
      electron_affinity = EXCLUDED.electron_affinity,
      electronegativity_pauling = EXCLUDED.electronegativity_pauling,
      ionization_energies = EXCLUDED.ionization_energies,
      shells = EXCLUDED.shells,
      discovered_by = EXCLUDED.discovered_by,
      named_by = EXCLUDED.named_by,
      summary = EXCLUDED.summary,
      source_url = EXCLUDED.source_url,
      cpk_hex = EXCLUDED.cpk_hex,
      spectral_img = EXCLUDED.spectral_img,
      bohr_model_image = EXCLUDED.bohr_model_image,
      bohr_model_3d = EXCLUDED.bohr_model_3d,
      image_url = EXCLUDED.image_url,
      image_title = EXCLUDED.image_title,
      image_attribution = EXCLUDED.image_attribution,
      xpos = EXCLUDED.xpos,
      ypos = EXCLUDED.ypos,
      wxpos = EXCLUDED.wxpos,
      wypos = EXCLUDED.wypos;
  `;

  let inserted = 0;
  for (const e of db.elements) {
    await client.query(insertSQL, [
      e.number,
      e.symbol,
      e.name,
      e.atomic_mass ?? null,
      e.category ?? null,
      e.appearance ?? null,
      e.phase ?? null,
      e.block ?? null,
      e.period ?? null,
      e.group ?? null,
      e.density ?? null,
      e.melt ?? null,
      e.boil ?? null,
      e.molar_heat ?? null,
      e.electron_configuration ?? null,
      e.electron_configuration_semantic ?? null,
      e.electron_affinity ?? null,
      e.electronegativity_pauling ?? null,
      e.ionization_energies ?? null,
      e.shells ?? null,
      e.discovered_by ?? null,
      e.named_by ?? null,
      e.summary ?? null,
      e.source ?? null,
      e['cpk-hex'] ?? null,
      e.spectral_img ?? null,
      e.bohr_model_image ?? null,
      e.bohr_model_3d ?? null,
      e.image?.url ?? null,
      e.image?.title ?? null,
      e.image?.attribution ?? null,
      e.xpos ?? null,
      e.ypos ?? null,
      e.wxpos ?? null,
      e.wypos ?? null,
    ]);
    inserted++;
  }

  console.log(`Inserted/updated ${inserted} elements`);

  const { rows } = await client.query('SELECT count(*) AS total FROM periodic_elements');
  console.log(`Total rows in periodic_elements table: ${rows[0].total}`);

  const sample = await client.query(
    'SELECT atomic_number, symbol, name, atomic_mass, category, density FROM periodic_elements ORDER BY atomic_number LIMIT 5'
  );
  console.log('Sample rows:');
  console.table(sample.rows);

  await client.end();
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
