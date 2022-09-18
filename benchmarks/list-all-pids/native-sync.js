import fs from 'node:fs';

function list() {
  fs.readdirSync('/proc');
}

list();
