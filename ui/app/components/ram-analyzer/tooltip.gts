import { DefaultTooltip, tooltipFor } from './tooltips';
import velcro from 'ember-velcro/modifiers/velcro';
import load from 'ember-async-data/helpers/load';
import { on } from '@ember/modifier';

import { Panel } from 'ui/components/ui';

import type { TOC } from '@ember/component/template-only';
import type { ProcessInfo } from './info';

const idFor = (process: ProcessInfo) => `text#pid-${process.pid}`;

export const Tooltip: TOC<{
  Element: HTMLDivElement;
  Args: {
    process?: ProcessInfo;
    onEnter?: () => void;
  }
}> =
  <template>
    {{#if @process}}
      <Panel
        ...attributes
        class="grid gap-2 shadow-2xl"
        {{velcro (idFor @process)}}
      >


        {{! Types are incorrect for load }}

        {{! @glint-ignore }}
        {{#let (load (tooltipFor @process.name)) as |state|}}

          {{! @glint-ignore }}
          {{#if state.isResolved}}
            {{! @glint-ignore }}
            {{#if state.value}}

              {{! @glint-ignore }}
              <state.value />
              <hr class="border-0.5 border-indigo-500/50" />

            {{/if}}

          {{/if}}

        {{/let}}

        <DefaultTooltip @process={{@process}} />
      </Panel>
    {{/if}}
  </template>;
        // <button {{on 'click' @onEnter}}>
        //   Focus
        // </button>
        // <button {{on 'click' @onEnter}}>
        //   Up
        // </button>
