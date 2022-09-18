/* eslint-disable @typescript-eslint/no-explicit-any */
import { tracked } from '@glimmer/tracking';
// Using this API, because I don't want to install the ember-storage-primitives-polyfill
import { get, notifyPropertyChange } from '@ember/object';
import Service from '@ember/service';

function _stored(target: object, key: string, _descriptor: PropertyDescriptor) {
  return {
    configurable: true,
    enumerable: true,
    get() {
      let serialized = window.localStorage.getItem(`settings-${key}`);
      let parsed = JSON.parse(serialized || '{}');

      get(this, `_${key}`);

      return parsed.value;
    },
    set(value: unknown) {
      let deserialized = { value };
      let serialized = JSON.stringify(deserialized);

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
  @stored showTable = false;

  @tracked pause = false;

  // Status
  @tracked isPaused = false;
}

// DO NOT DELETE: this is how TypeScript knows how to look up your services.
declare module '@ember/service' {
  interface Registry {
    settings: Settings;
  }
}
