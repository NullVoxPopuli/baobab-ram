/**
  * Adapted from:
  *   https://codesandbox.io/s/sunburst-d3-react-ioop1?from-embed=&file=/src/SunburstChart.tsx
  *
  *   NOTE:
  *     - the react example was not implemented with TS strict mode, so there will be a smidge
  *       more code in this implementation for extra safety
  *     - the react component defined all functions within the component, which menas they're all
  *       re-declared each time the component updates. Since we want to be able to update the data,
  *       we needed to move things around a bit so that we could avoid memory thrashing.
  *     - the whole component sunburst component in the react example mixes behaviors and responsibilities,
  *       which is common in d3 demos, but it makes it hard to understand what is responsible for
  *       what and what the purpose / reasoning is.
  */
import Component from '@glimmer/component';
import { cached, tracked } from '@glimmer/tracking';
import { assert } from '@ember/debug';

/**
  * TODO: switch this to be _just what's used_.
  * As is, this loads the entirety of d3
  */
import * as d3 from 'd3';
import * as filesize  from 'filesize';

import { Info, type SunburstData } from './info';
import { autosize } from './autosize';

interface Signature {
  Args: {
    data: Info;
  }
}

interface Data {
  name: string;
  value?: number;
}


export class Sunburst extends Component<Signature> {
  <template>
    <svg {{autosize this.size this.updateSize}} width="100%" height="100%">
      <g fill-opacity={{0.6}}>
        {{#each (descendentsWithDepth this.root) as |node|}}
          <path fill={{this.getColor node}} d={{this.arc node}}>
            <text>{{nodeText node}}</text>
          </path>
        {{/each}}
      </g>
      <g pointer-events="none" text-anchor="middle" font-size=10 font-family="sans-serif">
        {{#each (descendentsWithReportableSize this.root) as |node|}}
          <text transform={{this.getTextTransform node}} dy="0.35em">{{node.data.name}}</text>
        {{/each}}
      </g>
    </svg>
  </template>

  @tracked size = 700;

  updateSize = (size: number) => this.size = size;

  get radius() {
    return this.size / 2;
  }

  get data() {
    return this.args.data.json;
  }

  @cached
  get root() {
    return partition(this.data, this.radius);
  }

  /**
    * Cached function - provides a color-getting function based on the number of
    * root childern
    */
  @cached
  get color() {
    return d3.scaleOrdinal(
      d3.quantize(d3.interpolateRainbow, this.data.children.length + 1)
    );
  }


  /**
    * Cached function - provides an arc-getting function based on the radius
    */
  @cached
  get arc() {
    return d3
      .arc<d3.HierarchyRectangularNode<Data>>()
      .startAngle((d) => d.x0)
      .endAngle((d) => d.x1)
      .padAngle((d) => Math.min((d.x1 - d.x0) / 2, 0.005))
      .padRadius(this.radius / 2)
      .innerRadius((d) => d.y0)
      .outerRadius((d) => d.y1 - 1);
  }

  getColor = (d: d3.HierarchyRectangularNode<Data>) => {
    let currentNode: null | d3.HierarchyRectangularNode<Data> = d;
    while (currentNode && currentNode.depth > 1) currentNode = currentNode.parent;

    assert(`Search for the parent node failed`, currentNode);

    return this.color(currentNode.data.name);
  };

  getTextTransform = (d: d3.HierarchyRectangularNode<Data>) => {
    const x = (((d.x0 + d.x1) / 2) * 180) / Math.PI;
    const y = (d.y0 + d.y1) / 2;

    return `rotate(${x - 90}) translate(${y},0) rotate(${x < 180 ? 0 : 180})`;
  };
}

const format = d3.format(",d");

function descendentsWithDepth(root: d3.HierarchyRectangularNode<Data>) {
  return root.descendants().filter(d => d.depth);
}

function descendentsWithReportableSize(root: d3.HierarchyRectangularNode<Data>) {
  return root
    .descendants()
    .filter((d) => d.depth && ((d.y0 + d.y1) / 2) * (d.x1 - d.x0) > 10);
}

function nodeText(node: d3.HierarchyRectangularNode<Data>) {
  return node
    .ancestors()
    .map((d) => d.data.name)
    .reverse()
    .join("/") + '\n' + format(node.value ?? 0);
}

function partition(data: SunburstData, radius: number) {
  return d3.partition<Data>().size([2 * Math.PI, radius])(
    d3
      .hierarchy(data)
      .sum((d) => d.value ?? 0)
      .sort((a, b) => (b.value ?? 0) - (a.value ?? 0))
  );
}
