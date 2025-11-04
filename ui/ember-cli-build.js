'use strict';;

const path = require('path');
const EmberApp = require('ember-cli/lib/broccoli/ember-app');
const stew = require('broccoli-stew');
const fse = require('fs-extra');

const {
  compatBuild
} = require("@embroider/compat");

function isProduction() {
  return EmberApp.env() === 'production';
}

module.exports = async function(defaults) {
  const {
    buildOnce
  } = await import("@embroider/vite");

  const app = new EmberApp(defaults, {
    // Add options here
  });

  const rootTree = require('@embroider/compat').compatBuild(app, Webpack, {
    staticAddonTestSupportTrees: true,
    staticAddonTrees: true,
    staticHelpers: true,
    staticModifiers: false,
    staticComponents: true,
    staticAppPaths: true,
    skipBabel: [
      {
        package: 'qunit',
      },
    ],
    packagerOptions: {
      // publicAssetURL is used similarly to Ember CLI's asset fingerprint prepend option.
      publicAssetURL: '/',
      // Embroider lets us send our own options to the style-loader
      cssLoaderOptions: {
        // don't create source maps in production
        sourceMap: isProduction() === false,
        // enable CSS modules
        modules: {
          // global mode, can be either global or local
          // we set to global mode to avoid hashing tailwind classes
          mode: 'global',
          // class naming template
          localIdentName: isProduction() ? '[sha512:hash:base64:5]' : '[path][name]__[local]',
        },
      },
      webpackConfig: {
        optimization: {
          sideEffects: true,
          providedExports: true,
        },
        module: {
          rules: [
            {
              // When webpack sees an import for a CSS files
              test: /\.css$/i,
              exclude: /node_modules/,
              use: [
                {
                  // use the PostCSS loader addon
                  loader: 'postcss-loader',
                  options: {
                    sourceMap: isProduction() === false,
                    postcssOptions: {
                      config: './postcss.config.js',
                    },
                  },
                },
              ],
            },
            {
              test: /\.(png|svg|jpg|jpeg|gif|webp)$/i,
              type: 'asset/resource',
            },
          ],
        },
      },
    },
  });

  const dist = path.join(__dirname, 'dist');
  const target = path.join(__dirname, '..', 'ram-usage-analyzer/site-dist');

  if (process.argv.some((arg) => arg === 'test')) {
    // For tests, we can skip the afterBuild part
    return compatBuild(app, buildOnce);
  }

  return compatBuild(app, buildOnce);
};
