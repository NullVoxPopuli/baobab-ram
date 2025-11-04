import { Info } from "./info.gts";
import { Sunburst } from "./sunburst-d3";

export const RamAnalyzer = <template>
  <Info as |state|>
    {{#if state.isLoading}}
      Loading
    {{else if state.hasResults}}
      <Sunburst @data={{state}} />
    {{else}}
      Unknown error occurred
    {{/if}}
  </Info>
</template>;
