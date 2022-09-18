import type * as d3 from 'd3';

export interface Data {
  name: string;
  pid: string;
  value?: number;
}

export interface Size {
  x0: number;
  x1: number;
  y0: number;
  y1: number;
}

export type HierarchyNode = d3.HierarchyRectangularNode<Data> & {
  target: Size;
  current: Size;
};
