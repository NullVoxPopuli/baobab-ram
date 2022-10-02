import Component from '@glimmer/component';
import { assert } from '@ember/debug';
import { cached, tracked } from '@glimmer/tracking';
import Modifier from 'ember-modifier';
import { use } from 'ember-resources';

import * as d3 from 'd3';

import { service } from 'ui/helpers/service';

import { autosize } from './autosize';
import {
  Scale, Dimensions,
  scopedTo, partition, getSize, arcVisible, labelVisible,
  processForPid,
  MAX_VISIBLE_DEPTH, NULL_PID
} from './util';
import { ProcessTable } from './process-table';
import { Tooltip } from './tooltip';
import { Info, type SunburstData, type ProcessInfo } from './info';
import { type HierarchyNode } from './types';

export class Sunburst extends Component<{
  Args: {
    data: Info;
  }
}> {
  /**
    * Size of the chart / svg
    * This is arbitrary, as we need the chart to start with something.
    * After DOM measurements are taken, this will be updated by the
    * {{autosize}} modifier
    */
  @tracked size = 700;
  updateSize = (size: number) => this.size = size;

  /**
    * The current root process PID
    * In this current implementatino, d3 manages this, but will report changes
    * to it here.
    *
    * This allows us to filter the process table down to what's visible in the graph.
    *
    * TODO: make this the source of truth, not d3.
    */
  @tracked currentRoot = 1;
  updateRoot = (newPid: number) => this.currentRoot = newPid;

  @tracked hoveredProcess?: ProcessInfo;
  handleHover = (pid: number) => {
    if (this.blurFrame) cancelAnimationFrame(this.blurFrame);
    if (this.blurTimeout) clearTimeout(this.blurTimeout);

    let process = processForPid(pid, this.data);
    this.hoveredProcess = process;
  }
  blurFrame?: number;
  blurTimeout?: number;
  handleBlur = (pid: number) => {
    if (this.blurFrame) cancelAnimationFrame(this.blurFrame);
    if (this.blurTimeout) clearTimeout(this.blurTimeout);

    let delay = 200; //ms
    this.blurTimeout = setTimeout(() => {
      this.blurFrame = requestAnimationFrame(async () => {
        this.hoveredProcess = undefined;
        this.blurFrame = undefined;
        this.blurTimeout = undefined;
      });
    }, delay)
  }

  get data() {
    return this.args.data.json || NULL_PID;
  }

  @cached
  get scopedData() {
    return scopedTo(this.data, this.currentRoot);
  }

  /**
    * None if this is really ergonomic enough to be used individually as public API.
    * in particular, the way this.size is updated.
    *
    * Also, all reactivity about the chart is deferred to d3.
    * This could cause performance problems down the line on low-powered devices.
    *
    * TODO: investigate if manually typing out the SVG elements and attributes as
    *       elements and derived computations is worth the cost of figuring out
    *       how to do that.
    *
    *       The main downside to using the template as the reactive interface is that
    *       all d3 demos don't care about a consuming UI framework.
    *
    *       The problem is that d3 has its own reactivity, and has to diff our
    *       whole object every time we want to change anything, no matter how
    *       significant of a change it is.
    *       Right now, we hack a bunch of manual updates via the modifier's update/modify
    *       hook. This works, but is wasteful. For example, every time anything changes in
    *       the modifier's args, we re-render the free/allocated/total summary when those
    *       DOM nodes should 100% be left alone.
    *
    *       With fine-grained reactivity, such as what `@tracked` + auto-tracking
    *       provides, we can *most optimizedly* update single processes at a time
    *       (or even just a single property about thoseo processes).
    *
    *       Additionally, with fine-grained reactivity, we can pair down our d3 install
    *       to "just the math parts", and get rid of all the rendering sub-packages.
    *       This is likely ideal for low-connectivity, low-powered devices.
    *
    *       Where it could get tricky is the modelling of sibling data and calculating
    *       overall size / percent of the arcs.
    *       But FUD shouldn't keep us from trying, investigating, and reporting back to
    *       the community with results.
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
          updateRoot=this.updateRoot
          onHover=this.handleHover
          onBlur=this.handleBlur
        }}
      ></svg>

      {{#let (service 'settings') as |settings|}}
        {{#if settings.showTable}}
          <ProcessTable @data={{this.scopedData}} />
        {{/if}}
      {{/let}}

      <Tooltip @process={{this.hoveredProcess}} />
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
      updateRoot: (newPid: number) => void;
      onHover: (pid: number) => void;
      onBlur: (pid: number) => void;
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
  declare updateRoot: (pid: number) => void;
  declare handleHover: (pid: number) => void;
  declare handleBlur: (pid: number) => void;

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
    this.updateRoot = named.updateRoot;
    this.handleHover = named.onHover;
    this.handleBlur = named.onBlur;

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
          .attr('class', 'arc outline:none focus:ring-offset-2 focus:ring')
          .attr('tabindex', '0')
          .each(d => d.current = d)
          .attr("fill", d => {
            let ancestor: HierarchyNode | null | undefined = d;

            while (ancestor && (ancestor.data?.memory || 0) > 1000 && (ancestor.depth || 0) > 1) {
              ancestor = ancestor?.parent;
            }

            // TODO: Find percent of ancestor's ring

            return this.scale.color(`${( ancestor ?? d).data.pid}`);
          })
          .attr('id', d => `pid-${d.data.pid}`)
          .attr("d", d => this.dimensions.arc(d.current))
          .attr("fill-opacity", d => arcVisible(d.current) ? (d.depth / MAX_VISIBLE_DEPTH) : 0)
          .attr("pointer-events", d => arcVisible(d.current) ? "auto" : "none")
          .on('mouseover', (_, d) => this.handleHover(d.data.pid))
          .on('mouseout', (_, d) => this.handleBlur(d.data.pid)),

        update => update.transition()
          .duration(200)
          .attr("d", d => this.dimensions.arc(d.current)),
        exit => exit.remove()
      );

    this.selections.paths.filter(d => Boolean(d.children?.length))
      .style("cursor", "pointer")
      // .on('click', (_, d) => this.handleHover(d.data.pid))
      .on("click", this.clicked);

    this.selections.labels = this.selections.labelG
      .selectAll('.label')
      .data(firstDescendant, (d) => (d as HierarchyNode).data.pid)
      .join(
        enter => enter
          .append('text')
          .attr('class', 'label')
          .attr("dy", "0.35em")
          .attr('id', d => `pid-${d.data.pid}`)
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
    let backNode = p.parent || this.root;
    this.parent.datum(backNode);

    this.updateRoot(p.data.pid);

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


