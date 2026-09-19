import React from "react";
import { Dashboard } from "./components.jsx";

const metrics = [{ value: "4", label: "Ready" }, { value: "2", label: "Review" }, { value: "1", label: "Blocked" }];
const rows = [
  { work: "Navigation", owner: "Web", due: "Today" },
  { work: "Source inspection", owner: "Docs", due: "Today" },
  { work: "Mobile layout", owner: "Design", due: "Tomorrow" },
  { work: "Release checklist", owner: "Ops", due: "Friday" }
];

export default function DashboardApp() {
  const blocked = Number(metrics.find((metric) => metric.label === "Blocked").value);
  const badgeLabel = blocked <= 1 ? "ON TRACK" : "AT RISK";
  return <Dashboard title="Release readiness" metrics={metrics} rows={rows} badgeLabel={badgeLabel} includeStatus={false} />;
}
