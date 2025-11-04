import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { service } from "@ember/service";

import Modifier from "ember-modifier";
import { link } from "reactiveweb/link";

import { Checkbox, Form, Panel, Select } from "./ui";

import type Settings from "#services/settings.ts";

/**
 * This could probably be its own service,
 * but it needs a better DX.
 *
 * Maybe:
 *
 *   @use serializer = Service(FormSettings);
 *   ->
 *   @service(FormSettings) serializer;
 *
 * Goal:
 *  - App-wide Singleton, based on class key
 *  - Automatic owner and destruction linking
 *
 *  See:
 *    https://github.com/emberjs/ember.js/issues/20095
 *    https://github.com/NullVoxPopuli/ember-resources/issues/622
 *
 * To discuss:
 *  - how to recommend inline definition, vs centrol location.
 *    inline is useful for small apps, demos, etc -- but for larger projects,
 *    you're gonna want to follow the common pattern of placing things in
 *    app/services
 *  - Why Service?
 *    - this type of class has no state, and would be extra work to tear down
 *      and re-instantiate each time.
 *      Due to no internal state, it can easily be shared with other instances of
 *      consumers.
 *    - We don't have the concept of "function that has access to other services".
 *      This service _could be_ "just a function", if the settings service were passed to it.
 */
class FormSettings {
  @service declare settings: Settings;

  update = (key: string, value?: FormDataEntryValue | null) => {
    // Ignore any value that is not a string (Files)
    if (value instanceof File) return;

    switch (key) {
      case "refreshRate": {
        const parsed = parseInt(`${value}`, 10);

        return this.updateIfDifferent("refreshRate", parsed);
      }
      // The booleans/checkboxes can all be treated the same
      case "pause":
      case "backgroundRefresh":
      case "showTable":
        return this.updateIfDifferent(key, value === "on");
    }
  };

  updateIfDifferent<Key extends keyof Settings>(
    key: Key,
    value: Settings[Key],
  ) {
    if (this.settings[key] !== value) {
      this.settings[key] = value;
    }
  }
}

export class SettingsPanel extends Component {
  @service declare settings: Settings;

  @link serializer = new FormSettings();

  handleInput = (event: Event) => {
    const form = event.currentTarget;

    assert(
      "event.currentTarget must be a <form> element",
      form instanceof HTMLFormElement,
    );

    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());

    /**
     * Need to get all fields manually, because checkboxes don't
     * report their "unchecked" value -- "unchecked" is implicit
     * when FormData omits them entirely.
     */
    for (const field of form.elements) {
      const name = field.getAttribute("name");

      if (!name) continue;

      const value = data[name];

      this.serializer.update(name, value);
    }
  };

  <template>
    <Panel>
      <Form
        @onInput={{this.handleInput}}
        class="grid gap-2"
        {{valuesFromStorage}}
      >
        <Select @name="refreshRate">
          <option value="1">1 s</option>
          <option value="2">2 s</option>
          <option value="5">5 s</option>
          <option value="10">10 s</option>
        </Select>

        {{! Convert to switch }}

        <Checkbox @name="pause" />
        <Checkbox @name="backgroundRefresh" />
        <Checkbox @name="showTable" />

        {{#if this.settings.isPaused}}
          <hr />
          <span>Automatic refresh paused</span>
        {{/if}}
      </Form>
    </Panel>
  </template>
}

class ValuesFromStorage extends Modifier {
  @service declare settings: Settings;

  modify(form: HTMLFormElement) {
    for (const element of form.elements) {
      const name = element.getAttribute("name");

      if (!name) continue;

      const value = this.settings[name as keyof Settings];

      if (element instanceof HTMLSelectElement) {
        const options = element.querySelectorAll("option");

        for (const option of options) {
          if (option.getAttribute("value") === `${value as string}`) {
            option.setAttribute("selected", "true");

            break;
          }
        }
      } else if (element instanceof HTMLInputElement) {
        const type = element.getAttribute("type");

        switch (type) {
          case "checkbox": {
            if (value) {
              element.checked = Boolean(value);
            }

            break;
          }

          default: {
            element.value = `${value as string}`;
          }
        }
      }
    }
  }
}

const valuesFromStorage = ValuesFromStorage;
