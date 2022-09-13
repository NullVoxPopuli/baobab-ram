import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { underscore } from '@ember/string';
import { type TOC } from '@ember/component/template-only';

const handleSubmit = (handleInput: (event: Event) => void, event: Event) => {
  event.preventDefault();
  handleInput(event);
};

export const Form: TOC<{
  Element: HTMLFormElement;
  Args: { onInput: (event: Event) => void }
  Blocks: { default: [] }
}> = <template>
  <form
    {{on 'submit' (fn handleSubmit @onInput)}}
    {{on 'input' @onInput}}
    ...attributes
  >
    {{yield}}
  </form>
</template>;

export const Panel: TOC<{ Blocks: { default: [] }}> = <template>
  <div class="drop-shadow shadow p-4 backdrop-blur rounded bg-white/45">
    {{yield}}
  </div>
</template>;

const toWords = (a: string) => underscore(a).replace('_', ' ');
const or = (a: string | undefined, b: string | undefined) => a || b || '';

export const Checkbox: TOC<{
  Element: HTMLInputElement;
  Args: { label?: string; name: string }
}> = <template>
  <label>
    {{toWords (or @label @name)}}
    <input type="checkbox" name={{@name}} ...attributes />
  </label>
</template>;

export const Select: TOC<{
  Element: HTMLSelectElement;
  Args: { label?: string; name: string }
  Blocks: { default: [] }
}> = <template>
  <label class="items-center grid grid-flow-col grid-cols-2 gap-1" >
    <span>{{toWords (or @label @name)}}</span>
    <select
      class="
        form-select appearance-none
        w-full
        px-2 py-0 m-0
        bg-white bg-clip-padding bg-no-repeat
        border border-solid border-gray-300
        rounded
      "
      name={{@name}}
      ...attributes
    >
      {{yield}}
    </select>
  </label>
</template>;

