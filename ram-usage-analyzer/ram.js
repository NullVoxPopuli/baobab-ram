import { exec } from 'node:child_process';
import fs from 'node:fs/promises';
import * as util from 'node:util';

// likely 4096 aka 4KB
let pageSize;

export async function collectRAMUsage() {
  try {
    await getPageSize();

    return await pidRamUsage();
  } catch (e) {
    console.error(e.message);

    return { error: e.message };
  }
}

async function getPageSize() {
  if (pageSize) return;

  await new Promise((resolve, reject) => {
    exec('getconf PAGESIZE', (err, stdout) => {
      if (err) {
        return reject(err);
      }

      const output = stdout.toString().trim();

      const _pageSize = parseInt(output, 10);

      pageSize = _pageSize;

      resolve(_pageSize);
    });
  });
}

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

  const proc = process.env.PROC_PATH || '/proc';

  let allPids = await fs.readdir(proc);

  allPids = allPids.map((pid) => parseInt(pid, 10)).filter(Boolean);

  const stats = new Map();
  const childrenOf = new Map();

  await Promise.allSettled(
    allPids.map(async (pid) => {
      // https://man7.org/linux/man-pages/man5/proc.5.html
      const statm = await fs.readFile(`${proc}/${pid}/statm`);
      const statmFile = statm.toString();
      const [_vm, rss, shared, _text, _lib, _data] = statmFile.split(' ');
      const comm = await fs.readFile(`${proc}/${pid}/comm`);
      const commFile = comm.toString().trim();
      const cmdline = (await fs.readFile(`${proc}/${pid}/cmdline`)).toString().trim();

      const stat = await fs.readFile(`${proc}/${pid}/stat`);
      const statLine = stat.toString();
      const [, rest] = statLine.split(`(${commFile}) `);
      // console.log({ statLine })
      const parts = rest.split(' ');
      const ppid = parseInt(parts[1], 10);
      // let vss = parts[20];
      // let rss = parts[21];

      childrenOf.set(ppid, [...(childrenOf.get(ppid) || []), pid]);
      stats.set(pid, {
        pid,
        name: commFile,
        command: cmdline,
        // These are all measured in "pages"
        // To get bytes: * 4096 as a page is 4kb
        memory: (rss - shared) * pageSize,
        // size       (1) total program size
        //            (same as VmSize in /proc/[pid]/status)
        // resident   (2) resident set size
        //            (inaccurate; same as VmRSS in /proc/[pid]/status)
        // shared     (3) number of resident shared pages
        //            (i.e., backed by a file)
        //            (inaccurate; same as RssFile+RssShmem in
        //            /proc/[pid]/status)
        rss: rss * pageSize,
        // vss,
        shared: shared * pageSize,
      });
    })
  );

  const childrenFor = (pidStats) => {
    const children = (childrenOf.get(pidStats.pid) || [])
      .map((childPid) => stats.get(childPid))
      .filter(Boolean);

    if (children.length === 0) {
      // Just return pidStats once value is migrated away from
      return {
        ...pidStats,
        value: pidStats.memory,
      };
    }

    return {
      ...pidStats,
      value: pidStats.memory,
      children: children.map((child) => {
        return childrenFor(child);
      }),
    };
  };

  /**
   * Now that we have all the stats, we need to form these into tree...
   * which... it would be great if pidtree provided this
   */
  const rootStat = stats.get(1);
  const root = childrenFor(rootStat);

  // console.log(util.inspect(root, false, 5, true));

  return root;
}
