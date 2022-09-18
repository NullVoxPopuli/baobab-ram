import { tracked } from '@glimmer/tracking';
import { isDestroyed, isDestroying, registerDestructor } from '@ember/destroyable';
import { service } from '@ember/service';

import { Resource, use } from 'ember-resources';

import type Settings from 'ui/services/settings';

export type NestedSunburstData =
  | { name: string; pid: string; value?: never; children: NestedSunburstData[] }
  | { name: string; pid: string; value: number };

export type SunburstData = {
  pid: string;
  name: string;
  value?: never;
  children: NestedSunburstData[];
};

export class Info extends Resource {
  @service declare settings: Settings;

  @tracked json?: SunburstData;

  /**
   * the root PID, 1, is what spawns
   * all subsequent sub-processes
   */
  @tracked currentRootPid = 1;

  @tracked totalMemory = 0;
  @tracked freeMemory = 0;

  get allocatedMemory() {
    return this.totalMemory - this.freeMemory;
  }

  get isLoading() {
    return Object.keys(this.json || {}).length === 0;
  }

  get hasResults() {
    return !this.isLoading;
  }

  @use socket = RAMSocket.from(() => ({
    handleMessage: (event: MessageEvent, ctx: RAMSocket) => {
      let json = JSON.parse(event.data);

      if ('totalMemory' in json) {
        this.totalMemory = json.totalMemory;
      }

      if ('freeMemory' in json) {
        this.freeMemory = json.freeMemory;
      }

      if ('processes' in json) {
        // TODO: instead of invalidating the whole object,
        //       recursively apply only the changes
        //       - memory values
        //       - added processes
        //       - removed processes
        //
        //       But does d3 do this for us?
        this.json = json.processes;

        // Our polling is kinda fake, in that we don't actually request every {interval}
        // we must wait until we receive a response before trying to queue another "ask"
        ctx.poll();
      }
    },
  }));

  modify() {
    if (this.settings.pause) {
      this.socket.pause();
    } else {
      this.socket.resume();
    }
  }
}

const ONE_SECOND = 1_000;

class RAMSocket extends Resource<{
  Named: {
    handleMessage: (event: MessageEvent, socket: RAMSocket) => void;
  };
}> {
  @service declare settings: Settings;

  declare websocket: WebSocket;

  isPaused = false;

  modify(_: never[], named: { handleMessage: (event: MessageEvent, socket: RAMSocket) => void }) {
    this.websocket = new WebSocket('ws://localhost:3000/ws');

    this.websocket.onopen = () => {
      this.send({ type: 'total' });
      this.send({ type: 'processes' });
    };

    this.websocket.onmessage = (event) => {
      if (this.isPaused) return;
      named.handleMessage(event, this);
    };

    window.addEventListener('blur', this.stopPoll);
    window.addEventListener('focus', this.poll);

    registerDestructor(this, () => {
      this.websocket.close();

      window.removeEventListener('blur', this.stopPoll);
      window.removeEventListener('focus', this.poll);
    });
  }

  send = (payload: unknown) => {
    this.websocket.send(JSON.stringify(payload));
  };

  pause = () => {
    this.isPaused = true;

    clearTimeout(this.polling);
    this.polling = setTimeout(this.poll, this.settings.refreshRate * ONE_SECOND);
  };
  resume = () => {
    this.isPaused = false;
  };

  polling?: number;
  poll = () => {
    // check again at the interval to see if we've unpaused
    if (this.isPaused) {
      clearTimeout(this.polling);

      this.polling = setTimeout(this.poll, this.settings.refreshRate * ONE_SECOND);

      return;
    }

    if (this.settings.pause) return;

    if (this.polling) {
      clearTimeout(this.polling);
    }

    this.settings.isPaused = false;

    this.polling = setTimeout(() => {
      if (isDestroyed(this) || isDestroying(this)) return;

      this.polling = undefined;
      this.send({ type: 'total' });
      this.send({ type: 'processes' });
    }, this.settings.refreshRate * ONE_SECOND);
  };
  stopPoll = () => {
    if (this.settings.backgroundRefresh) return;

    clearTimeout(this.polling);
    this.settings.isPaused = true;
    this.polling = undefined;
  };
}
