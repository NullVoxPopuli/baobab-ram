import { Info, type SunburstData, type NestedSunburstData } from './info';
import { Panel } from '../ui';
import { type TOC } from '@ember/component/template-only';

export const ProcessTable: TOC<{
  Args: {
    data: Info;
  }
}> = <template>
  <Panel class='h-full'>
    <table>
      <thead>
        <tr>
          <th>PID</th>
          <th>Name</th>
          <th>RSS</th>
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
      data: SunburstData | NestedSunburstData;
    }
  }
}> = <template>
  <tr>
    <td>{{@data.pid}}</td>
    <td>{{@data.name}}</td>
    <td>{{@data.value}}</td>
  </tr>

  {{! @glint-ignore }}
  {{#each @data.children as |child|}}
    <Row @data={{child}} />
  {{/each}}
</template>;
