import type { TOC } from "@ember/component/template-only";

export const ExternalLink: TOC<{
  Element: HTMLAnchorElement;
  Blocks: {
    default: [];
  };
}> = <template>
  <a
    href="#"
    target="_blank"
    rel="nofollow noopener noreferrer external"
    class="underline text-blue hover:text-blue-700 px-2 py-1 focusable focus:outline-none interactive-quiet rounded-sm transition"
    ...attributes
  >{{yield}}</a>
</template>;
