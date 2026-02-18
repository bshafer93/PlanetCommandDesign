import { Router, type Request, type Response } from 'express';
import { writeFileSync } from 'fs';
import { join, basename } from 'path';
import { DATA_DIR } from '../index.js';

export const materialsRouter = Router();

materialsRouter.post('/materials', (req: Request, res: Response) => {
  const { filename, data } = req.body;


});
