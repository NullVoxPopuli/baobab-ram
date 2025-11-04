import { configs } from "@nullvoxpopuli/eslint-configs";

// accommodates: JS, TS, App, Addon, and V2 Addon
export default [
  ...configs.ember(import.meta.dirname),
  {
    name: "local:disables",
    files: ["**/*"],
    rules: {
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
    },
  },
];
