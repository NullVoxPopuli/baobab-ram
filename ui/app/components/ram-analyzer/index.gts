import { Info } from './info';
import { Sunburst } from './sunburst-d3';
import { ProcessTable } from './process-table';
import { service } from 'ui/helpers/service';

<template>
  {{#let (Info) as |data|}}
    {{#if data.isLoading}}
      Loading
    {{else if data.hasResults}}
      <div class='w-full h-full grid grid-flow-col gap-2'>
        <Sunburst @data={{data}} />
        {{#let (service 'settings') as |settings|}}
          {{#if settings.showTable}}
            <ProcessTable @data={{data}} />
          {{/if}}
        {{/let}}
      </div>
    {{else}}
      Unknown error occurred
    {{/if}}
  {{/let}}
</template>
