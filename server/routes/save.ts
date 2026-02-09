import { Router, type Request, type Response } from 'express';
import { writeFileSync } from 'fs';
import { join, basename } from 'path';
import { DATA_DIR } from '../index.js';

export const saveRouter = Router();

saveRouter.post('/save', (req: Request, res: Response) => {
  const { filename, data } = req.body;

  if (!filename || typeof filename !== 'string') {
    res.status(400).json({ error: 'Missing or invalid filename' });
    return;
  }

  if (data === undefined) {
    res.status(400).json({ error: 'Missing data' });
    return;
  }

  // Sanitize: strip any path components, allow only alphanumeric, dash, underscore
  const safe = basename(filename).replace(/[^a-zA-Z0-9_-]/g, '');
  if (!safe) {
    res.status(400).json({ error: 'Filename contains no valid characters' });
    return;
  }

  const filePath = join(DATA_DIR, `${safe}.json`);

  try {
    writeFileSync(filePath, JSON.stringify(data, null, 2));
    res.json({ ok: true, file: `${safe}.json` });
  } catch (err) {
    console.error('Failed to write file:', err);
    res.status(500).json({ error: 'Failed to save file' });
  }
});
