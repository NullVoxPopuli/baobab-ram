import EmberRouter from "@ember/routing/router";

import { pageTitle } from "ember-page-title";
import PageTitleService from "ember-page-title/services/page-title";
import Application from "ember-strict-application-resolver";

import { RamAnalyzer } from "./components/ram-analyzer/index.gts";
import { SettingsPanel } from "./components/settings.gts";

class Router extends EmberRouter {
  location = "history";
  rootURL = "/";
}

Router.map(function () {
  // no routes
});

export default class App extends Application {
  modules = {
    "./router": Router,
    "./services/page-title": PageTitleService,
    ...import.meta.glob("./services/*.ts", { eager: true }),
    "./templates/index": <template>
      <div class="w-full h-full">
        <RamAnalyzer />
      </div>

      <div class="fixed top-0 left-0 z-1">
        <SettingsPanel />
      </div>
    </template>,
    "./templates/application": <template>
      {{pageTitle "RAM Usage Analyzer"}}

      {{outlet}}
    </template>,
  };
}
