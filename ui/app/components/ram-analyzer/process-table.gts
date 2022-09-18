import { Info, type SunburstData } from './info';
import { Panel } from '../ui';
import { type TOC } from '@ember/component/template-only';

import { getSize } from './util';

const ROOT_CACHE = new WeakMap<SunburstData, Map<number, number>>();

function sum(nums?: number[]) {
  return ( nums || []).reduce((total, current) => total + current, 0);
}

function totalRSS(node: SunburstData, root = node): number {
  let cache = ROOT_CACHE.get(root);

  if (!cache) {
    cache = new Map();
    ROOT_CACHE.set(root, new Map());
  }

  let existing = cache.get(node.pid);
  if (existing) {
    return existing;
  }


  let value = 0;

  value += sum(node.children?.map((child) => totalRSS(child, root)));

  let result = value + node.memory;
  cache.set(node.pid, result);

  return result;
}

export const ProcessTable: TOC<{
  Args: {
    data: Info;
  }
}> = <template>
  <Panel class='h-full fixed right-0 top-0 bottom-0 bg-white/70'>
    <table class="table-auto">
      <thead>
        <tr>
          <th>PID</th>
          <th>Name</th>
          <th>Memory</th>
        </tr>
      </thead>
      <tbody>
        {{#if @data.json}}
          <Row @data={{@data.json}} />
        {{/if}}
      </tbody>
    </table>
  </Panel>
</template>;

// const hasChildren = (node: SunburstData | NestedSunburstData) => Boolean('children' in node);

const Row: TOC<{
  Args: {
    Named: {
      data: SunburstData;
    }
  }
}> = <template>
  <tr>
    <td>{{@data.pid}}</td>
    <td>{{@data.name}}</td>
    <td>{{getSize @data.memory}}</td>
  </tr>

  {{! @glint-ignore }}
  {{#each @data.children as |child|}}
    <Row @data={{child}} />
  {{/each}}
</template>;
