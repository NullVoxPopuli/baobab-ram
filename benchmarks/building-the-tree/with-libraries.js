import pidtree from 'pidtree';
import pidusage from 'pidusage';
import find from 'find-process';

/**
 * So... RAM calculation is a mess.
 *
 * ps (cli tool)
 *  - RSS: shared memory, will overlap with other programs that load the same shared libraries
 *  - VSS: virtual memory, often not all of this is loaded into physical memory
 *  - does not show the *name* of the program, but does show the command
 * /proc/{id}/{info-file}
 *  - contain everything
 *  - multiple files need to be accessed to get a full picture
 *  - MacOS does not use /proc -- it seems all Linux distro do tho.
 *  - Windows does not use /proc
 */
async function pidRamUsage() {
  let allPids = await pidtree(-1);

  let stats = new Map();
  let childrenOf = new Map();

  await Promise.allSettled(
    allPids.map(async (pid) => {
      let result = await find('pid', pid);
      let usage = await pidusage(pid);
      let stat = {
        ...result[0],
        ...usage,
      };

      if (!stat) return;

      childrenOf.set(stat.ppid, [...(childrenOf.get(stat.ppid) || []), pid]);
      stats.set(pid, stat);
    })
  );

  const childrenFor = (pidStats) => {
    let children = (childrenOf.get(pidStats.pid) || [])
      .map((childPid) => stats.get(childPid))
      .filter(Boolean);

    if (children.length === 0) {
      return {
        pid: `${pidStats.pid}`,
        name: pidStats.name,
        value: pidStats.memory,
      };
    }

    return {
      name: pidStats.name,
      pid: '1',
      children: [
        {
          pid: `${pidStats.pid}-self`,
          name: `${pidStats.name} (self)`,
          value: pidStats.memory,
        },
        ...children.map((child) => {
          return childrenFor(child);
        }),
      ],
    };
  };

  /**
   * Now that we have all the stats, we need to form these into tree...
   * which... it would be great if pidtree provided this
   */
  let rootStat = stats.get(1);
  let root = childrenFor(rootStat);

  // console.log(util.inspect(root, false, 5, true));

  return root;
}

await pidRamUsage();
