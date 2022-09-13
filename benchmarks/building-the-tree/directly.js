import util from 'node:util';
import fs from 'node:fs/promises';

/**
  * References
  * - https://betterprogramming.pub/a-memory-friendly-way-of-reading-files-in-node-js-a45ad0cc7bb6
  *
  *
  * Information Needed
  * - pid
  * - ppid
  * - name
  * - memory (RSS)
  */
export async function pidRamUsage() {
  /**
    * The /proc/{pid}/stat file is way smaller,
    * yet informationally dense - thus should be
    * faster to read
    *
    * See docs for column assignments
    * https://man7.org/linux/man-pages/man5/proc.5.html
    * Columns of interest:
    * - ppid 3 (1-idx: 4)
    * - vss 22 (1-idx: 23) -- maybe later
    * - rss 23 (1-idx: 24)
    *
    *   We can't use the name from this file, because it's truncated to 16 characters
    *
    * The /proc/{pid}/statm file is even smaller
    * 0 - total program size, same as VmSize in status
    * 1 - RSS
    *
    * Some of these values are inaccurate because of a kernel-internal scalability optimization
    *
    * smaps_rollup contains accurate calculations, but is updated more slowly
    * https://www.kernel.org/doc/Documentation/ABI/testing/procfs-smaps_rollup
    */

  let allPids = await fs.readdir('/proc');

  allPids = allPids.map(pid => parseInt(pid, 10)).filter(Boolean);

  let stats = new Map();
  let childrenOf = new Map();

  await Promise.allSettled(
    allPids.map(async (pid) => {
      // let statm = await fs.readFile('/proc/1/statm');
      // let statmFile = statm.toString();
      // let [vm, rss] = statmFile.split(' ');
      let comm = await fs.readFile(`/proc/${pid}/comm`);
      let commFile = comm.toString().trim();

      let stat = await fs.readFile(`/proc/${pid}/stat`);
      let statLine = stat.toString();
      let [, rest] = statLine.split(`(${commFile}) `);
      // console.log({ statLine })
      let parts = rest.split(' ')
      let ppid = parseInt(parts[1], 10);
      // let vss = rest[]
      let rss = parts[21]

      childrenOf.set(ppid, [...(childrenOf.get(ppid) || []), pid]);
      stats.set(pid, {
        pid,
        name: commFile,
        memory: rss,
      })
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
