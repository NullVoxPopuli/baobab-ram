import { getSize } from '../util';

import type { TOC } from '@ember/component/template-only';
import type { ProcessInfo } from '../info';


export const DefaultTooltip: TOC<{
  Args: {
    process: ProcessInfo;
  }
}> = <template>
  <table class="table-auto text-left border-spacing-x-4 border-separate">
    <tbody>
      <tr><th scope="row">PID</th>   <td>{{@process.pid}}</td></tr>
      <tr><th scope="row">Name</th>  <td>{{@process.name}}</td></tr>
      <tr><th scope="row">Memory</th><td>{{getSize @process.memory}}</td></tr>
      <tr><th scope="row">RSS</th>   <td>{{getSize @process.rss}}</td></tr>
      <tr><th scope="row">Shared</th><td>{{getSize @process.shared}}</td></tr>
    </tbody>
  </table>
</template>;

