import * as d3 from 'd3';
import { resource, resourceFactory } from 'ember-resources';

import type { SunburstData } from './info';
import type { Data, HierarchyNode, Size } from './types';

export const Dimensions = resourceFactory((sizeFn) => {
  return resource(() => {
    let size = sizeFn();
    let radius = 100; // size / 2;

    return {
      width: size,
      height: size,
      radius,
      labelTransform: (d: Size) => {
        let x = (((d.x0 + d.x1) / 2) * 180) / Math.PI;
        let y = ((d.y0 + d.y1) / 2) * radius;

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
    let data = dataFn();

    let helpers = {
      color: d3.scaleOrdinal(d3.quantize(d3.interpolateRainbow, data.children.length + 1)),
    };

    return helpers;
  });
});

export const format = d3.format(',d');

export function partition(data: SunburstData): d3.HierarchyRectangularNode<Data> {
  let root = d3
    .hierarchy<Data>(data)
    .sum((d) => d.value ?? 0)
    .sort((a, b) => (b.value ?? 0) - (a.value ?? 0));

  let partitioned = d3.partition<Data>().size([2 * Math.PI, root.height + 1])(root);

  return partitioned;
}

export function arcVisible(d: Size) {
  return d.y1 <= 10 && d.y0 >= 1 && d.x1 > d.x0;
}

export function labelVisible(d: Size) {
  return d.y1 <= 10 && d.y0 >= 1 && (d.y1 - d.y0) * (d.x1 - d.x0) > 0.03;
}
