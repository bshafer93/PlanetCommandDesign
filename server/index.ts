import express from 'express';
import cors from 'cors';
import { mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { saveRouter } from './routes/save.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
export const DATA_DIR = join(__dirname, 'data');

mkdirSync(DATA_DIR, { recursive: true });

const app = express();
const PORT = 3001;

app.use(cors());
app.use(express.json());

app.use('/api', saveRouter);

app.listen(PORT, () => {
  console.log(`Backend server listening on http://localhost:${PORT}`);
});
