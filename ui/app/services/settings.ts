import { tracked } from "@glimmer/tracking";
// Using this API, because I don't want to install the ember-storage-primitives-polyfill
import { get, notifyPropertyChange } from "@ember/object";
import Service from "@ember/service";

function _stored(target: object, key: string, _descriptor: PropertyDescriptor) {
  return {
    configurable: true,
    enumerable: true,
    get() {
      const serialized = window.localStorage.getItem(`settings-${key}`);
      // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
      const parsed = JSON.parse(serialized || "{}");

      get(this, `_${key}`);

      // eslint-disable-next-line @typescript-eslint/no-unsafe-return, @typescript-eslint/no-unsafe-member-access
      return parsed.value;
    },
    set(value: unknown) {
      const deserialized = { value };
      const serialized = JSON.stringify(deserialized);

      window.localStorage.setItem(`settings-${key}`, serialized);
      notifyPropertyChange(this, `_${key}`);
    },
  };
}

const stored: PropertyDecorator = _stored as unknown as PropertyDecorator;

export default class Settings extends Service {
  // The Actual Settings
  @stored refreshRate = 1;
  @stored backgroundRefresh = false;
  @stored showTable = true;

  @tracked pause = false;

  // Status
  @tracked isPaused = false;
}

// DO NOT DELETE: this is how TypeScript knows how to look up your services.
declare module "@ember/service" {
  interface Registry {
    settings: Settings;
  }
}
