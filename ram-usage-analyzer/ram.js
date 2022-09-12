import pidtree from 'pidtree';
import pidusage from 'pidusage';

export async function collectRAMUsage() {
  try {
    return await pidRamUsage();
  } catch (e) {
    console.error(e.message);
    return { error: e.message };
  }
}

async function pidRamUsage() {
  let allPids = await pidtree(-1);

  console.log(allPids.length);

  /**
    * Getting pid stats individually is faster than sending an array to pidusage
    * (by 4x)
    */
  let stats = await Promise.allSettled(allPids.map(pid => pidusage(pid)));

  /**
    * Now that we have all the stats, we need to form these into tree...
    * which... it would be great if pidtree provided this
    */
  console.log(stats.length)
  console.log(await pidusage(1))
  console.log(await pidtree(1));
  // console.log(stats.map(stat => stat.value));
}
