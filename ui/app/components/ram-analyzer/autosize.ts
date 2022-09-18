import { assert } from '@ember/debug';
import { isDestroyed, isDestroying, registerDestructor } from '@ember/destroyable';

import Modifier from 'ember-modifier';

type Positional = [updateSize: (newSize: number) => void];

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

    let [updateSize] = positional;

    this.parentElement = element.parentElement;

    assert(
      `parent of of the element where {{autosize}} was applied does not exist`,
      this.parentElement
    );

    if (!this.isSetup) {
      this.updateSize = updateSize;
      this.isSetup = true;

      window.addEventListener('resize', this.requestUpdateSize);
      element.setAttribute('viewBox', viewBoxFor(this.parentElement));

      registerDestructor(this, () => {
        window.removeEventListener('resize', this.requestUpdateSize);
      });

      this.requestUpdateSize();
    }

    // element.setAttribute('width', `${size}`);
    // element.setAttribute('height', `${size}`);
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
    let parentStyles = getComputedStyle(this.parentElement);

    let xPadding = parseFloat(parentStyles.paddingLeft) + parseFloat(parentStyles.paddingRight);
    let yPadding = parseFloat(parentStyles.paddingTop) + parseFloat(parentStyles.paddingBottom);

    let { width, height } = rect;

    let smaller = Math.min(width - xPadding, height - yPadding);

    this.updateSize(smaller);
  };
}

function viewBoxFor(element: Element) {
  // but let's put 0,0 in the middle
  let { x, y, width, height } = element.getBoundingClientRect();

  return `${x},${y},${width},${height}`;
}

export const autosize = Autosize;
