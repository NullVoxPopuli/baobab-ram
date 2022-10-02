import type { ComponentLike } from '@glint/template';

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
export { DefaultTooltip } from './-default';

export async function tooltipFor(processName: string): Promise<ComponentLike | undefined> {
  let module;

  switch (processName) {
    case 'firefox':
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      module = await import('./firefox');

      break;
    default:
      return;
  }

  return module.default;
}
