import fs from 'node:fs/promises';

async function list() {
  await fs.readdir('/proc');
}

await list();
