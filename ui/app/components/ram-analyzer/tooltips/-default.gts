import { getSize } from '../util';

import type { ProcessInfo } from '../info';
import type { TOC } from '@ember/component/template-only';


export const DefaultTooltip: TOC<{
  Args: {
    process: ProcessInfo;
  }
}> = <template>
  <table class="table-auto text-left border-spacing-x-4 border-separate">
    <tbody>
      <tr><th scope="row">PID</th>   <td>{{@process.pid}}</td></tr>
      <tr><th scope="row">Name</th>  <td>{{@process.name}}</td></tr>
      <tr><th scope="row">Command</th>  <td>{{@process.command}}</td></tr>
    </tbody>
  </table>
</template>;

