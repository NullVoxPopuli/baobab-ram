import { Info } from './info';
import { Sunburst } from './sunburst';

<template>
  {{#let (Info) as |data|}}
    <Sunburst @data={{data}} />
  {{/let}}
</template>
