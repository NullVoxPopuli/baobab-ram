import { Info } from './info';
import { Sunburst } from './sunburst-d3';

<template>
  {{#let (Info) as |data|}}
    {{#if data.isLoading}}
      Loading
    {{else if data.hasResults}}
      <Sunburst @data={{data}} />
    {{else}}
      Unknown error occurred
    {{/if}}
  {{/let}}
</template>
