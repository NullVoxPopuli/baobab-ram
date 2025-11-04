import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { on } from "@ember/modifier";

import * as d3 from "d3";
import Modifier from "ember-modifier";
import { service } from "ember-primitives/helpers/service";
import { use } from "ember-resources";

import { autosize } from "./autosize";
import { ProcessTable } from "./process-table";
import { Tooltip } from "./tooltip";
import { type HierarchyNode } from "./types";
import {
  arcVisible,
  Dimensions,
  getSize,
  labelVisible,
  MAX_VISIBLE_DEPTH,
  NULL_PID,
  partition,
  processForPid,
  Scale,
  scopedTo,
} from "./util";

import type { Info, ProcessInfo, SunburstData } from "./info.gts";

export class Sunburst extends Component<{
  Args: {
    data: Info;
  };
}> {
  /**
   * Size of the chart / svg
   * This is arbitrary, as we need the chart to start with something.
   * After DOM measurements are taken, this will be updated by the
   * {{autosize}} modifier
   */
  @tracked size = 700;
  updateSize = (size: number) => (this.size = size);

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
  updateRoot = (newPid: number) => (this.currentRoot = newPid);

  @tracked hoveredProcess?: ProcessInfo;
  handleHover = (pid: number) => {
    if (this.blurFrame) cancelAnimationFrame(this.blurFrame);
    if (this.blurTimeout) clearTimeout(this.blurTimeout);

    const process = processForPid(pid, this.data);

    this.hoveredProcess = process;
  };

  zoomToRoot = () => {
    // Find the Sun modifier and trigger a click on the root
    const sunModifier = this.sunModifierInstance;
    if (sunModifier && sunModifier.root) {
      // Simulate clicking on the root to zoom all the way out
      sunModifier.clicked(new Event('click'), sunModifier.root);
    }
  };

  sunModifierInstance?: Sun;
  setSunModifierRef = (modifier: Sun) => {
    this.sunModifierInstance = modifier;
  };
  blurFrame?: number;
  blurTimeout?: number;
  handleBlur = (pid: number) => {
    if (this.blurFrame) cancelAnimationFrame(this.blurFrame);
    if (this.blurTimeout) clearTimeout(this.blurTimeout);

    const delay = 200; //ms

    this.blurTimeout = setTimeout(() => {
      this.blurFrame = requestAnimationFrame(() => {
        this.hoveredProcess = undefined;
        this.blurFrame = undefined;
        this.blurTimeout = undefined;
      });
    }, delay);
  };

  get data() {
    return this.args.data.json || NULL_PID;
  }

  @cached
  get scopedData() {
    return scopedTo(this.data, this.currentRoot);
  }

  get showZoomToRootButton() {
    // Show button when not at the root (PID 1)
    return this.currentRoot !== 1;
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
    <div class="w-full h-full relative">
      <svg
        width="100%"
        height="100%"
        {{autosize this.updateSize}}
        {{Sun
          this.data
          this.size
          free=(getSize @data.freeMemory)
          allocated=(getSize @data.allocatedMemory)
          total=(getSize @data.totalMemory)
          updateRoot=this.updateRoot
          onHover=this.handleHover
          onBlur=this.handleBlur
          setModifierRef=this.setSunModifierRef
        }}
      ></svg>

      {{! Zoom to root button - only show when not at root }}
      {{#if this.showZoomToRootButton}}
        <button
          type="button"
          class="absolute bottom-4 left-4 bg-blue-600 hover:bg-blue-700 text-white rounded-full p-2 shadow-lg transition-colors duration-200 z-10"
          title="Zoom to root"
          {{on "click" this.zoomToRoot}}
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>
          </svg>
        </button>
      {{/if}}

      {{#let (service "settings") as |settings|}}
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
  paths: d3.Selection<
    d3.BaseType | SVGPathElement,
    HierarchyNode,
    SVGGElement,
    unknown
  >;

  labelG: d3.Selection<SVGGElement, unknown, any, unknown>;
  labels: d3.Selection<
    d3.BaseType | SVGTextElement,
    HierarchyNode,
    SVGGElement,
    unknown
  >;

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
      setModifierRef?: (modifier: Sun) => void;
    };
  };
}

class Sun extends Modifier<Signature> {
  @use dimensions = Dimensions(() => this.size);
  @use scale = Scale(() => this.data);

  selections: Partial<Selections> = {};
  activeTransition?: d3.Transition<any, any, any, any>;
  lastClickTime = 0;
  clickDebounceMs = 100; // Prevent rapid clicks

  // Add state management for race condition prevention
  isTransitioning = false;
  pendingUpdate = false;
  lastDataUpdateId = 0;
  currentDataId = 0;

  declare root: HierarchyNode;
  declare forLater: [SunburstData, number];
  declare container: Element;
  declare updateRoot: (pid: number) => void;
  declare handleHover: (pid: number) => void;
  declare handleBlur: (pid: number) => void;

  declare parent: d3.Selection<
    SVGCircleElement,
    HierarchyNode,
    null,
    undefined
  >;

  get data() {
    return this.forLater[0];
  }

  get size() {
    return this.forLater[1];
  }

  isSetup = false;
  currentZoomNode?: HierarchyNode;

  modify(
    element: Element,
    positional: Signature["Args"]["Positional"],
    named: Signature["Args"]["Named"],
  ) {
    this.container = element;
    this.forLater = positional;
    this.updateRoot = named.updateRoot;
    this.handleHover = named.onHover;
    this.handleBlur = named.onBlur;

    // Store reference to this modifier instance
    if (named.setModifierRef) {
      named.setModifierRef(this);
    }

    // Increment data ID to track data changes
    this.currentDataId++;

    if (!this.isSetup) {
      this.setup();
      this.isSetup = true;
      this.lastDataUpdateId = this.currentDataId;
    } else {
      // Check if we're in the middle of a user-initiated transition
      if (this.isTransitioning) {
        // Mark that we have a pending update and return early
        this.pendingUpdate = true;
        return;
      }

      this.processDataUpdate();
    }

    this.selections.freeMemory?.text(`${named.free} Free`);
    this.selections.allocatedMemory?.text(`${named.allocated} Allocated`);
    this.selections.totalMemory?.text(`${named.total} Total`);
  }

  processDataUpdate() {
    // Preserve zoom state during updates
    const previousZoomNode = this.currentZoomNode;
    const previousZoomPid = previousZoomNode?.data.pid;

    // Store current visual state before updating data (preserve zoom state)
    const preservedCurrentState = new Map();
    const preservedTargetState = new Map();
    if (this.root) {
      this.root.descendants().forEach(d => {
        preservedCurrentState.set(d.data.pid, { ...d.current });
        if (d.target) {
          preservedTargetState.set(d.data.pid, { ...d.target });
        }
      });
    }

    // Update data structure
    this.root = partition(this.data) as HierarchyNode;

    // Initialize with base state only if we don't have preserved state
    if (!previousZoomNode) {
      this.root.each((d) => (d.current = d));
    }

    // If we were zoomed to a specific node, try to find and restore that state
    if (previousZoomNode && previousZoomPid) {
      const newZoomNode = this.findNodeByPid(this.root, previousZoomPid);
      if (newZoomNode) {
        this.currentZoomNode = newZoomNode;

        // Restore visual states for existing nodes, initialize new nodes appropriately
        this.root.descendants().forEach(d => {
          const preservedCurrent = preservedCurrentState.get(d.data.pid);
          const preservedTarget = preservedTargetState.get(d.data.pid);

          if (preservedCurrent) {
            // Existing node - restore its visual state
            d.current = preservedCurrent;
            if (preservedTarget) {
              d.target = preservedTarget;
            }
          } else {
            // New node - initialize with appropriate zoom state
            const target = {
              x0: Math.max(0, Math.min(1, (d.x0 - newZoomNode.x0) / (newZoomNode.x1 - newZoomNode.x0))) * 2 * Math.PI,
              x1: Math.max(0, Math.min(1, (d.x1 - newZoomNode.x0) / (newZoomNode.x1 - newZoomNode.x0))) * 2 * Math.PI,
              y0: Math.max(0, d.y0 - newZoomNode.depth),
              y1: Math.max(0, d.y1 - newZoomNode.depth),
            };
            d.current = target;
            d.target = target;
          }
        });

        // Update parent circle for zoom-out behavior
        const backNode = newZoomNode.parent || this.root;
        if (this.parent) {
          this.parent.datum(backNode);
        }
      } else {
        // The zoomed node no longer exists, reset to root
        this.currentZoomNode = undefined;
        this.updateRoot(this.root.data.pid);
        this.root.each((d) => (d.current = d));
      }
    } else {
      // No zoom state to preserve, initialize normally
      this.root.each((d) => (d.current = d));
    }

    // Only call update if no active transition is running
    if (!this.activeTransition) {
      this.update();
    }

    this.lastDataUpdateId = this.currentDataId;
  }

  update = () => {
    const firstDescendant = this.root.descendants().slice(1);

    if (!this.selections.pathG) return;
    if (!this.selections.labelG) return;

    this.selections.paths = this.selections.pathG
      .selectAll(".arc")
      .data(firstDescendant, (d) => (d as HierarchyNode).data.pid)
      .join(
        (enter) => {
          return enter
            .append("path")
            .attr(
              "class",
              `arc
                  focus:outline-none focus:stroke-2 focus:stroke-blue-500 hover:drop-shadow-md`,
            )
            .attr("tabindex", "0")
            .each((d) => (d.current = d))
            .attr("fill", (d) => {
              let ancestor: HierarchyNode | null | undefined = d;

              while (
                ancestor &&
                (ancestor.data?.memory || 0) > 1000 &&
                (ancestor.depth || 0) > 1
              ) {
                ancestor = ancestor?.parent;
              }

              // TODO: Find percent of ancestor's ring

              return this.scale.color(`${(ancestor ?? d).data.pid}`);
            })
            .attr("id", (d) => `pid-${d.data.pid}`)
            .attr("d", (d) => this.dimensions.arc(d.current))
            .attr("fill-opacity", (d) =>
              arcVisible(d.current) ? d.depth / MAX_VISIBLE_DEPTH : 0,
            )
            .attr("pointer-events", (d) =>
              arcVisible(d.current) ? "auto" : "none",
            )
            .on("mouseover", (_, d) => this.handleHover(d.data.pid))
            .on("mouseout", (_, d) => this.handleBlur(d.data.pid));
        },

        (update) =>
          update
            .transition()
            .duration(200)
            .attr("fill-opacity", (d) =>
              arcVisible(d.current) ? d.depth / MAX_VISIBLE_DEPTH : 0,
            )
            .attr("pointer-events", (d) =>
              arcVisible(d.current) ? "auto" : "none",
            )
            .attr("d", (d) => this.dimensions.arc(d.current)),
        (exit) => exit.remove(),
      );

    this.selections.paths
      .filter((d) => Boolean(d.children?.length))
      .style("cursor", "pointer")
      // .on('click', (_, d) => this.handleHover(d.data.pid))
      .on("click", this.clicked);

    this.selections.labels = this.selections.labelG
      .selectAll(".label")
      .data(firstDescendant, (d) => (d as HierarchyNode).data.pid)
      .join(
        (enter) =>
          enter
            .append("text")
            .attr("class", "label")
            .attr("dy", "0.35em")
            .attr("id", (d) => `pid-${d.data.pid}`)
            .attr("fill-opacity", (d) => +labelVisible(d.current ?? d))
            .attr("transform", (d) => this.dimensions.labelTransform(d.current))
            .text((d) => d.data.name),
        (update) =>
          update
            .transition()
            .duration(200)
            .attr("fill-opacity", (d) => +labelVisible(d.current ?? d))
            .attr("transform", (d) =>
              this.dimensions.labelTransform(d.current),
            ),
        (exit) => exit.remove(),
      );
  };

  setup() {
    const { width, radius } = this.dimensions;

    const root = partition(this.data) as HierarchyNode;

    root.each((d) => (d.current = d));
    this.root = root;

    const translate = `translate(${width},${width / 2})`;

    const svg = d3
      .select(this.container)
      .style("font", "12px sans-serif")
      .attr("preserveAspectRatio", "xMinYMid");

    const zoom = d3
      .zoom()
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
    this.selections.pathG = g.append("g").attr("transform", translate);
    this.selections.labelG = g
      .append("g")
      .attr("transform", translate)
      .attr("pointer-events", "none")
      .attr("text-anchor", "middle")
      .style("user-select", "none");

    this.update();

    this.parent = g
      .append("circle")
      .datum(root)
      .attr("r", radius)
      .attr("transform", translate)
      .attr("fill", "none")
      .attr("pointer-events", "all")
      .on("click", this.clicked);

    this.selections.stats = g
      .append("g")
      .attr("transform", translate)
      .attr("pointer-events", "none")
      .attr("text-anchor", "middle");

    this.selections.freeMemory = this.selections.stats
      .append("text")
      .attr("dy", "-1.2em");
    this.selections.allocatedMemory = this.selections.stats
      .append("text")
      .attr("dy", "0em");
    this.selections.totalMemory = this.selections.stats
      .append("text")
      .attr("dy", "1.2em");
  }

  findNodeByPid(root: HierarchyNode, targetPid: number): HierarchyNode | null {
    // Early return for exact match
    if (root.data.pid === targetPid) {
      return root;
    }

    // Early return if no children
    if (!root.children?.length) {
      return null;
    }

    // Search children
    for (const child of root.children) {
      const found = this.findNodeByPid(child, targetPid);
      if (found) return found;
    }

    return null;
  }

  applyZoomState(zoomNode: HierarchyNode, preserveCurrent = false) {
    // Don't cancel transitions here as this might be called during data updates
    // Only apply state synchronously for immediate visual consistency

    // Calculate zoom transforms
    this.root.each((d) => {
      const target = {
        x0:
          Math.max(0, Math.min(1, (d.x0 - zoomNode.x0) / (zoomNode.x1 - zoomNode.x0))) * 2 * Math.PI,
        x1:
          Math.max(0, Math.min(1, (d.x1 - zoomNode.x0) / (zoomNode.x1 - zoomNode.x0))) * 2 * Math.PI,
        y0: Math.max(0, d.y0 - zoomNode.depth),
        y1: Math.max(0, d.y1 - zoomNode.depth),
      };
      d.target = target;

      // Only update current if we're not preserving the visual state
      if (!preserveCurrent) {
        d.current = target;
      }
    });

    // Update parent circle for zoom-out behavior
    const backNode = zoomNode.parent || this.root;
    if (this.parent) {
      this.parent.datum(backNode);
    }

    // Force immediate update of visuals only if no active transition and not preserving state
    if (!this.isTransitioning && !preserveCurrent) {
      this.updateVisuals();
    }
  }

  cancelActiveTransition() {
    if (this.selections.paths) {
      this.selections.paths.interrupt();
    }
    if (this.selections.labels) {
      this.selections.labels.interrupt();
    }
    this.activeTransition = undefined;
    this.isTransitioning = false;

    // Process any pending updates after transition is cancelled
    this.processPendingUpdates();
  }

  processPendingUpdates() {
    if (this.pendingUpdate && this.currentDataId > this.lastDataUpdateId) {
      this.pendingUpdate = false;
      this.processDataUpdate();
    }
  }

  updateVisuals() {
    // Update paths immediately without animation
    if (this.selections.paths) {
      this.selections.paths
        .attr("fill-opacity", (d) =>
          arcVisible(d.current) ? d.depth / MAX_VISIBLE_DEPTH : 0,
        )
        .attr("pointer-events", (d) =>
          arcVisible(d.current) ? "auto" : "none",
        )
        .attr("d", (d) => this.dimensions.arc(d.current));
    }

    // Update labels immediately without animation
    if (this.selections.labels) {
      this.selections.labels
        .attr("fill-opacity", (d) => +labelVisible(d.current))
        .attr("transform", (d) => this.dimensions.labelTransform(d.current));
    }
  }

  clicked = (_event: Event, p: HierarchyNode) => {
    // Debounce rapid clicks to prevent glitching
    const now = Date.now();
    if (now - this.lastClickTime < this.clickDebounceMs) {
      return;
    }
    this.lastClickTime = now;

    // Cancel any ongoing transitions first
    this.cancelActiveTransition();

    // Mark that we're starting a user-initiated transition
    this.isTransitioning = true;

    const backNode = p.parent || this.root;
    this.parent.datum(backNode);

    // If clicking the root node or going back to parent, reset zoom state
    if (p === this.root || p.parent === null || p.data.pid === this.root.data.pid) {
      this.currentZoomNode = undefined;
    } else {
      this.currentZoomNode = p; // Track the current zoom state
    }

    this.updateRoot(p.data.pid);

    // Calculate target positions for animation (don't set current immediately)
    this.root.each((d) => {
      d.target = {
        x0:
          Math.max(0, Math.min(1, (d.x0 - p.x0) / (p.x1 - p.x0))) * 2 * Math.PI,
        x1:
          Math.max(0, Math.min(1, (d.x1 - p.x0) / (p.x1 - p.x0))) * 2 * Math.PI,
        y0: Math.max(0, d.y0 - p.depth),
        y1: Math.max(0, d.y1 - p.depth),
      };
    });

    if (!this.selections.rootG) return;
    if (!this.selections.paths) return;

    // Transition the data on all arcs, even the ones that aren't visible,
    // so that if this transition is interrupted, entering arcs will start
    // the next transition from the desired position.
    const pathTransition = this.selections.paths
      .transition()
      .duration(700)
      .tween("data", (d) => {
        const i = d3.interpolate(d.current, d.target);

        return (t) => (d.current = i(t));
      })
      .filter(function (d) {
        assert(
          "path member isnt an SVGPathElement",
          this instanceof SVGPathElement,
        );

        const opacity = this.getAttribute("fill-opacity");

        if (!opacity) return arcVisible(d.target);

        return parseFloat(opacity) > 0 || arcVisible(d.target);
      })
      .attr("fill-opacity", (d) =>
        arcVisible(d.target) ? d.depth / MAX_VISIBLE_DEPTH : 0,
      )
      .attr("pointer-events", (d) => (arcVisible(d.target) ? "auto" : "none"))
      .attrTween("d", (d) => () => {
        const arcPath = this.dimensions.arc(d.current);

        // bug in d3 where arc returns potentially null?
        // maybe a math thing I don't understand that could end up with null?
        assert(`Arc tween path failed to be created`, arcPath);

        return arcPath;
      })
      .on("end", () => {
        // Clear the active transition when animation completes
        this.activeTransition = undefined;
        this.isTransitioning = false;
        // Process any pending updates after transition completes
        this.processPendingUpdates();
      })
      .on("interrupt", () => {
        // Handle transition interruption
        this.activeTransition = undefined;
        this.isTransitioning = false;
        this.processPendingUpdates();
      });

    if (!this.selections.labels) return;

    this.selections.labels
      .filter(function (d: any) {
        assert(
          "label member isnt an SVGTextElement",
          this instanceof SVGTextElement,
        );

        const opacity = (this as SVGTextElement).getAttribute("fill-opacity");

        if (!opacity) return labelVisible(d.target);

        return parseFloat(opacity) > 0 || labelVisible(d.target);
      })
      .transition()
      .duration(700)
      .attr("fill-opacity", (d: any) => +labelVisible(d.target))
      .attrTween(
        "transform",
        (d: any) => () => this.dimensions.labelTransform(d.current),
      );

    // Track the active transition (use path transition as primary)
    this.activeTransition = pathTransition as any;
  };

  willDestroy() {
    // Clean up any active transitions and timers when the modifier is destroyed
    this.cancelActiveTransition();
    this.pendingUpdate = false;
    this.isTransitioning = false;
  }
}
