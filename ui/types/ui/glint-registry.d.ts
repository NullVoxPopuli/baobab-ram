import "@glint/environment-ember-loose";
import "@glint/environment-ember-loose/native-integration";
import "ember-page-title/glint";

import type { HelperLike } from '@glint/template';


declare module "@glint/environment-ember-loose/registry" {
  export default interface Registry {
    // How to define globals from external addons
    // state: HelperLike<{ Args: {}, Return: State }>;
    // attachShadow: ModifierLike<{ Args: { Positional: [State['update']]}}>;

    /**
     *  Components
     */

    /**
     * Helpers
     */
     'page-title': HelperLike<{ Args: { Positional: [string] }, Return: void}>,

    /**
     * Modifiers
     */
  }
}
