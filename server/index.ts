import express from 'express';
import cors from 'cors';
import { mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { saveRouter } from './routes/save.js';
import { orbitRouter } from './routes/orbit.js';
import { closePool } from './lib/dal.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
export const DATA_DIR = join(__dirname, 'data');

mkdirSync(DATA_DIR, { recursive: true });

const app = express();
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 3001;

app.use(cors());
app.use(express.json());

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/api', saveRouter);
app.use('/api', orbitRouter);

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server listening on http://0.0.0.0:${PORT}`);
});

function shutdown() {
  console.log('Shutting down...');
  server.close(() => {
    closePool().then(() => process.exit(0));
  });
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
