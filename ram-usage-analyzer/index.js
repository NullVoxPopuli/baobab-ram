#!/usr/bin/env node

import process from "node:process";
import { boot } from "./server.js";

let versionParts = process.version.split(".");

let [major, minor] = versionParts;

let majorN = major.replace("v", "");

if (parseInt(majorN) <= 22 && parseInt(minor) < 16) {
  throw new Error(
    `Node ${process.version} is too old for this tool. Please use at least Node 22.16`,
  );
}

boot();
