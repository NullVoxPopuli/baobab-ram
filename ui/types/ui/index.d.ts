import type Ember from 'ember';
import '@glint/environment-ember-template-imports';

declare global {
  // Prevents ESLint from "fixing" this via its auto-fix to turn it into a type
  // alias (e.g. after running any Ember CLI generator)
  // eslint-disable-next-line @typescript-eslint/no-empty-interface
  interface Array<T> extends Ember.ArrayPrototypeExtensions<T> {}
  // interface Function extends Ember.FunctionPrototypeExtensions {}
}

import type { HelperLike, ModifierLike } from '@glint/template';

declare module '@ember/modifier' {
  export const on: ModifierLike<{
    Args: {
      Positional: [eventName: string, handler: (event: Event) => void]
    }
  }>;
}

declare module '@ember/helper' {
  export const fn: HelperLike<{
    Args: {
      Positional: [handler: (...args: any[]) => unknown]
    }
    Return: (...args: any[]) => unknown;
  }>;
}


export {};
