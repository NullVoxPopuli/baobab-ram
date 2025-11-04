import * as d3 from 'd3';
import { resource, resourceFactory } from 'ember-resources';
import * as filesize from 'filesize';

import type { ProcessInfo, SunburstData } from './info';
import type { Size } from './types';

export const MAX_VISIBLE_DEPTH = 10;

export const getSize = filesize.partial({ base: 2, standard: 'jedec' });

export const NULL_PID: SunburstData = {
  pid: 0,
  name: '<missing-data>',
  memory: 0,
  rss: 0,
  shared: 0,
  children: [],
};

export const scopedTo = (data: SunburstData, pid: number): SunburstData => {
  if (data.pid === pid) return data;

  for (const process of data.children ?? []) {
    const result = scopedTo(process, pid);

    if (result.pid === pid) return result;
  }

  return NULL_PID;
};

export const Dimensions = resourceFactory((sizeFn) => {
  return resource(() => {
    const size = sizeFn();
    const radius = 100; // size / 2;

    return {
      width: size,
      height: size,
      radius,
      labelTransform: (d: Size) => {
        const x = (((d.x0 + d.x1) / 2) * 180) / Math.PI;
        const y = ((d.y0 + d.y1) / 2) * radius;

        return `rotate(${x - 90}) translate(${y},0) rotate(${x < 180 ? 0 : 180})`;
      },
      arc: d3
        .arc<Size>()
        .startAngle((d) => d.x0)
        .endAngle((d) => d.x1)
        .padAngle((d) => Math.min((d.x1 - d.x0) / 2, 0.005))
        .padRadius(radius * 1.5)
        .innerRadius((d) => d.y0 * radius)
        .outerRadius((d) => Math.max(d.y0 * radius, d.y1 * radius - 1)),
    };
  });
});

export const Scale = resourceFactory((dataFn) => {
  return resource(() => {
    const data = dataFn();

    const max = data.children.length + 1;
    const helpers = {
      color: d3.scaleOrdinal(d3.quantize(d3.interpolateRainbow, max)),
    };

    return helpers;
  });
});

export const format = d3.format(',d');

export function partition(data: SunburstData): d3.HierarchyRectangularNode<ProcessInfo> {
  const root = d3
    .hierarchy<ProcessInfo>(data)
    .sum((d) => d.memory ?? 0)
    .sort((a, b) => (b.value ?? 0) - (a.value ?? 0));

  const partitioned = d3.partition<ProcessInfo>().size([2 * Math.PI, root.height + 1])(root);

  return partitioned;
}

export function arcVisible(d: Size) {
  return d.y1 <= 10 && d.y0 >= 1 && d.x1 > d.x0;
}

export function labelVisible(d: Size) {
  return d.y1 <= 10 && d.y0 >= 1 && (d.y1 - d.y0) * (d.x1 - d.x0) > 0.03;
}

const PID_TO_PROCESS_MAP_CACHE = new Map<number, ProcessInfo>();
let LAST_DATA: SunburstData | undefined;

export function processForPid(pid: number, data: SunburstData) {
  if (LAST_DATA === data) {
    const existing = PID_TO_PROCESS_MAP_CACHE.get(pid);

    if (existing) return existing;
  }

  LAST_DATA = data;

  const found = scopedTo(data, pid);

  PID_TO_PROCESS_MAP_CACHE.set(pid, found);

  return found;
}
