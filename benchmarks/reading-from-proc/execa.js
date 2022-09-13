import { execa } from 'execa';

await execa('cat', ['/proc/1/status']);
