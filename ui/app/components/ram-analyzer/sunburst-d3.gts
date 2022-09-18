import Component from '@glimmer/component';
import { assert } from '@ember/debug';
import { tracked } from '@glimmer/tracking';
import Modifier from 'ember-modifier';
import { use } from 'ember-resources';

import * as d3 from 'd3';

import { autosize } from './autosize';
import { Scale, Dimensions, partition, getSize, arcVisible, labelVisible, MAX_VISIBLE_DEPTH } from './util';
import { Info, type SunburstData, type ProcessInfo, NULL_PID } from './info';
import { type HierarchyNode } from './types';
import { ProcessTable } from './process-table';
import { service } from 'ui/helpers/service';

export class Sunburst extends Component<{
  Args: {
    data: Info;
  }
}> {
  @tracked size = 700;

  updateSize = (size: number) => this.size = size;

  get data() {
    return this.args.data.json || NULL_PID;
  }

  /**
    * None if this is really ergonomic enough to be used individually as public API.
    * in particular, the way this.size is updated.
    */
  <template>
    <div class='w-full h-full'>
      <svg
        width="100%" height="100%"
        {{autosize this.updateSize}}
        {{Sun this.data this.size
          free=(getSize @data.freeMemory)
          allocated=(getSize @data.allocatedMemory)
          total=(getSize @data.totalMemory)
        }}
      ></svg>

      {{#let (service 'settings') as |settings|}}
        {{#if settings.showTable}}
          <ProcessTable @data={{@data}} />
        {{/if}}
      {{/let}}
    </div>
  </template>
}

interface Selections {
  svg: d3.Selection<Element, unknown, any, unknown>;
  rootG: d3.Selection<SVGGElement, unknown, any, unknown>;
  pathG: d3.Selection<SVGGElement, unknown, any, unknown>;
  paths: d3.Selection<d3.BaseType | SVGPathElement, HierarchyNode, SVGGElement, unknown>;

  labelG: d3.Selection<SVGGElement, unknown, any, unknown>;
  labels: d3.Selection<d3.BaseType | SVGTextElement, HierarchyNode, SVGGElement, unknown>;

  stats: d3.Selection<SVGGElement, unknown, any, unknown>;
  freeMemory: d3.Selection<SVGTextElement, unknown, any, unknown>;
  allocatedMemory: d3.Selection<SVGTextElement, unknown, any, unknown>;
  totalMemory: d3.Selection<SVGTextElement, unknown, any, unknown>;
}

interface Signature {
  Args: {
    Positional: [data: SunburstData, size: number];
    Named: {
      free: string;
      allocated: string;
      total: string;
    }
  }
}

class Sun extends Modifier<Signature> {
  @use dimensions = Dimensions(() => this.size);
  @use scale = Scale(() => this.data);

  selections: Partial<Selections> = {};

  declare root: HierarchyNode;
  declare forLater: [SunburstData, number];
  declare container: Element;

  declare parent: d3.Selection<SVGCircleElement, HierarchyNode, null, undefined>;


  get data() {
    return this.forLater[0];
  }

  get size() {
    return this.forLater[1];
  }

  isSetup = false;
  modify(
    element: Element,
    positional: Signature['Args']['Positional'],
    named: Signature['Args']['Named']
  ) {
    this.container = element;
    this.forLater = positional;

    if (!this.isSetup) {
      this.setup();
      this.isSetup = true;
    } else {
      this.root = partition(this.data) as HierarchyNode;
      this.root.each(d => d.current = d);
      this.update();
    }

    this.selections.freeMemory?.text(`${named.free} Free`);
    this.selections.allocatedMemory?.text(`${named.allocated} Allocated`);
    this.selections.totalMemory?.text(`${named.total} Total`);
  }

  update = () => {
    let firstDescendant = this.root.descendants().slice(1);

    if (!this.selections.pathG) return;
    if (!this.selections.labelG) return;

    this.selections.paths = this.selections.pathG
      .selectAll('.arc')
      .data(firstDescendant, (d) => (d as HierarchyNode).data.pid)
      .join(
        enter => enter
          .append('path')
          .attr('class', 'arc')
          .each(d => d.current = d)
          .attr("fill", d => {
            let ancestor: HierarchyNode | null | undefined = d;

            while (ancestor && (ancestor.data?.memory || 0) > 1000 && (ancestor.depth || 0) > 1) {
              ancestor = ancestor?.parent;
            }

            // TODO: Find percent of ancestor's ring

            return this.scale.color(`${( ancestor ?? d).data.pid}`);
          })
          .attr("d", d => this.dimensions.arc(d.current))
          .attr("fill-opacity", d => arcVisible(d.current) ? (d.depth / MAX_VISIBLE_DEPTH) : 0)
          .attr("pointer-events", d => arcVisible(d.current) ? "auto" : "none"),

        update => update.transition()
          .duration(200)
          .attr("d", d => this.dimensions.arc(d.current)),
        exit => exit.remove()
      );

    this.selections.paths.filter(d => Boolean(d.children?.length))
      .style("cursor", "pointer")
      .on("click", this.clicked);

    this.selections.labels = this.selections.labelG
      .selectAll('.label')
      .data(firstDescendant, (d) => (d as HierarchyNode).data.pid)
      .join(
        enter => enter
          .append('text')
          .attr('class', 'label')
          .attr("dy", "0.35em")
          .attr("fill-opacity", d => +labelVisible(d.current ?? d))
          .attr("transform", d => this.dimensions.labelTransform(d.current))
          .text(d => d.data.name),
        update => update.transition()
          .duration(200)
          .attr("transform", d => this.dimensions.labelTransform(d.current)),
        exit => exit.remove(),
      );
  }

  setup() {
    let { width, radius } = this.dimensions;

    let root = partition(this.data) as HierarchyNode;
    root.each(d => d.current = d);
    this.root = root;
    let translate = `translate(${width},${width / 2})`;

    let svg = d3.select(this.container)
      .style("font", "12px sans-serif")
      .attr('preserveAspectRatio', 'xMinYMid');

    let zoom = d3.zoom()
      .scaleExtent([0, 6])
      .on("zoom", (event) => {
        const { transform } = event;

        if (!this.selections.rootG) return;

        this.selections.rootG.attr("transform", transform);
        this.selections.rootG.attr("stroke-width", 1 / transform.k);
      });

    svg.call(zoom);

    this.selections.svg = svg;

    const g = svg.append("g");

    this.selections.rootG = g;
    this.selections.pathG = g.append('g')
      .attr("transform", translate);
    this.selections.labelG = g
        .append('g')
        .attr("transform", translate)
        .attr("pointer-events", "none")
        .attr("text-anchor", "middle")
        .style("user-select", "none")

    this.update();

    this.parent = g.append("circle")
        .datum(root)
        .attr("r", radius)
        .attr("transform", translate)
        .attr("fill", "none")
        .attr("pointer-events", "all")
        .on("click", this.clicked);

    this.selections.stats = g.append('g')
      .attr("transform", translate)
      .attr('pointer-events', 'none')
      .attr('text-anchor', 'middle');

    this.selections.freeMemory = this.selections.stats.append('text').attr('dy', '-1.2em');
    this.selections.allocatedMemory = this.selections.stats.append('text').attr('dy', '0em');
    this.selections.totalMemory = this.selections.stats.append('text').attr('dy', '1.2em');
  }

  clicked = (_event: Event, p: HierarchyNode) => {
    this.parent.datum(p.parent || this.root);

    this.root.each(d => {
      d.target = {
        x0: Math.max(0, Math.min(1, (d.x0 - p.x0) / (p.x1 - p.x0))) * 2 * Math.PI,
        x1: Math.max(0, Math.min(1, (d.x1 - p.x0) / (p.x1 - p.x0))) * 2 * Math.PI,
        y0: Math.max(0, d.y0 - p.depth),
        y1: Math.max(0, d.y1 - p.depth)
      };
    });


    if (!this.selections.rootG) return;
    if (!this.selections.paths) return;

    // Transition the data on all arcs, even the ones that aren’t visible,
    // so that if this transition is interrupted, entering arcs will start
    // the next transition from the desired position.
    this.selections.paths
      .transition()
      .duration(700)
      .tween("data", d => {
        const i = d3.interpolate(d.current, d.target);

        return t => d.current = i(t);
      })
      .filter(function (d) {
        assert('path member isnt an SVGPathElement', this instanceof SVGPathElement);

        let opacity = this.getAttribute('fill-opacity');

        if (!opacity) return arcVisible(d.target);

        return parseFloat(opacity) > 0 || arcVisible(d.target);
      })
      .attr("fill-opacity", d => arcVisible(d.target) ? (d.depth / MAX_VISIBLE_DEPTH) : 0)
      .attr("pointer-events", d => arcVisible(d.target) ? "auto" : "none")
      .attrTween("d", d => () => {
        let arcPath = this.dimensions.arc(d.current)

        // bug in d3 where arc returns potentially null?
        // maybe a math thing I don't understand that could end up with null?
        assert(`Arc tween path failed to be created`, arcPath);

        return arcPath;
      });


    if (!this.selections.labels) return;

    this.selections.labels
      .filter(function (d) {
        assert('label member isnt an SVGTextElement', this instanceof SVGTextElement);

        let opacity = this.getAttribute('fill-opacity');

        if (!opacity) return labelVisible(d.target);

        return parseFloat(opacity) > 0 || labelVisible(d.target);
      })
      .transition()
      .duration(700)
      .attr("fill-opacity", d => +labelVisible(d.target))
      .attrTween("transform", d => () => this.dimensions.labelTransform(d.current));
  }
}


