import * as os from 'node:os';
import * as url from 'node:url';
import * as path from 'node:path';

import express from 'express';
import setupWS from 'express-ws';

import { collectRAMUsage } from './ram.js';

const __dirname = url.fileURLToPath(new URL('.', import.meta.url));

const ASSETS = path.join(__dirname, 'site-dist');
const PORT = 3000;
const HOST = 'localhost';

const welcome = () => {
  console.info(
    `===================================\n` +
      `       Ram Usage Analyzer\n` +
      `===================================\n` +
      `\n` +
      `🎉 Successfully started.\n\n` +
      `Visit: http://${HOST}:${PORT}\n\n`
  );
};

function parse(input) {
  try {
    return JSON.parse(input);
  } catch (e) {
    console.error(e);

    return { type: 'parsing-error', error: e.message };
  }
}

export function boot() {
  const app = express();

  setupWS(app);

  app.use(express.static(ASSETS, { etag: false }));

  app.ws('/ws', (ws, req) => {
    /**
     * type ToClientMessage =
     *   | { error: string }
     *   | { totalMemory: number; freeMemory: number }
     *   | { processes: { deep object formatted for d3 } }
     *
     * type FromClientMessage =
     *   | { type: 'total' }
     *   | { type: 'processes' }
     */
    ws.on('message', async (msg) => {
      let json = parse(msg);

      switch (json.type) {
        case 'total': {
          let totalMemory = os.totalmem();
          let freeMemory = os.freemem();

          ws.send(JSON.stringify({ totalMemory, freeMemory }));

          break;
        }
        case 'processes': {
          let data = await collectRAMUsage();

          ws.send(JSON.stringify({ processes: data }));

          break;
        }
        /**
         * We set "parsing-error" ourselves
         */
        case 'parsing-error': {
          ws.send(JSON.stringify({ error: json.error }));

          break;
        }
      }
    });
  });

  app.listen(PORT, welcome);
}
