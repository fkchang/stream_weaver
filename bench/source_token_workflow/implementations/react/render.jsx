import fs from "node:fs";
import path from "node:path";
import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import InitialDashboard from "./initial.jsx";
import RevisedDashboard from "./revised.jsx";

const root = path.resolve(import.meta.dirname, "../..");
const output = path.join(root, "tmp", "rendered");
fs.mkdirSync(output, { recursive: true });

for (const [filename, Component] of [["react-initial.html", InitialDashboard], ["react-revised.html", RevisedDashboard]]) {
  const body = renderToStaticMarkup(<Component />);
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Release readiness</title><link rel="stylesheet" href="dashboard.css"></head><body>${body}</body></html>`;
  fs.writeFileSync(path.join(output, filename), html);
}
