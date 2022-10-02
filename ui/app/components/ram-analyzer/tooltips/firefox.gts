import { ExternalLink } from 'ui/components/external-link';

const Processes =
  <template>
    <ExternalLink href="about:processes">
      about:processes
    </ExternalLink>
  </template>;

const Memory =
  <template>
    <ExternalLink href="about:memory?verbose">
      about:memory?verbose
    </ExternalLink>
  </template>;

<template>
  <div>
    Visit <Processes /> to manage tabs in Firefox.
    <br>
    or <Memory /> to manually manage Memory.
  </div>
</template>
