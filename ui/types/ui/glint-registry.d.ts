import "@glint/environment-ember-loose";
import "@glint/environment-ember-loose/native-integration";
import "ember-page-title/glint";

import type { HelperLike } from '@glint/template';
// @ts-ignore
import type RamAnalyzer from 'ui/components/ram-analyzer';
// @ts-ignore
import type Settings from 'ui/components/settings';

declare module "@glint/environment-ember-loose/registry" {
  export default interface Registry {
    // How to define globals from external addons
    // state: HelperLike<{ Args: {}, Return: State }>;
    // attachShadow: ModifierLike<{ Args: { Positional: [State['update']]}}>;

    /**
     *  Components
     */
     RamAnalyzer: typeof RamAnalyzer
     Settings: typeof Settings

    /**
     * Helpers
     */
     'page-title': HelperLike<{ Args: { Positional: [string] }, Return: void}>,

    /**
     * Modifiers
     */
  }
}
