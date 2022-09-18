import { execaCommand } from 'execa';

await execaCommand('cat /proc/1/status');
