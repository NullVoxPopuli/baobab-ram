import { assert } from '@ember/debug';
import { isDestroyed, isDestroying, registerDestructor } from '@ember/destroyable';

import Modifier from 'ember-modifier';

type Positional = [size: number, updateSize: (newSize: number) => void];

interface Signature {
  Args: {
    Positional: Positional;
  };
}

/**
 * Sets the width/height/viewbox for an svg element to fill the caintaining element
 */
class Autosize extends Modifier<Signature> {
  declare updateSize: (size: number) => void;
  declare parentElement?: HTMLElement | null;

  isSetup = false;
  modify(element: Element, positional: Positional) {
    assert(
      `{{autosize}} may only be used on an SVGElement. ` + `Instead received ${element.tagName}`,
      element instanceof SVGElement
    );

    let [size, updateSize] = positional;

    this.parentElement = element.parentElement;

    if (!this.isSetup) {
      this.updateSize = updateSize;
      this.isSetup = true;

      window.addEventListener('resize', this.requestUpdateSize);

      registerDestructor(this, () => {
        window.removeEventListener('resize', this.requestUpdateSize);
      });
    }

    // element.setAttribute('width', `${size}`);
    // element.setAttribute('height', `${size}`);
    element.setAttribute('viewBox', viewBoxFor(element));
  }

  frame?: number;
  requestUpdateSize = () => {
    if (this.frame) cancelAnimationFrame(this.frame);

    this.frame = requestAnimationFrame(this.handleResize);
  };

  handleResize = () => {
    if (isDestroyed(this) || isDestroying(this)) return;

    if (!this.parentElement) return;

    let rect = this.parentElement.getBoundingClientRect();

    let { width, height } = rect;

    let smaller = Math.min(width, height);

    let newSize = smaller;

    this.updateSize(newSize);
  };
}

function viewBoxFor(element: SVGElement) {
  assert(`expected element to have a BBox`, element instanceof SVGGraphicsElement);

  let { x, y, width, height } = element.getBBox();

  return `${x},${y},${width},${height}`;
}

export const autosize = Autosize;
