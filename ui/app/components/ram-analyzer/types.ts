import type { ProcessInfo } from './info';
import type * as d3 from 'd3';

export interface Size {
  x0: number;
  x1: number;
  y0: number;
  y1: number;
}

export type HierarchyNode = d3.HierarchyRectangularNode<ProcessInfo> & {
  target: Size;
  current: Size;
};
