import pidtree from 'pidtree';
import pidusage from 'pidusage';
import find from 'find-process';

let allPids = await pidtree(-1);

await Promise.allSettled(allPids.map(async pid => {
  await find('pid', pid)
  await pidusage(pid);
}));
