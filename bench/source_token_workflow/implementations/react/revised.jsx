import React from "react";
import { Dashboard } from "./components.jsx";

const metrics = [{ value: "4", label: "Ready" }, { value: "2", label: "Review" }, { value: "1", label: "Blocked" }];
const rows = [
  { work: "Navigation", owner: "Web", due: "Today", status: "Ready" },
  { work: "Source inspection", owner: "Docs", due: "Today", status: "Review" },
  { work: "Mobile layout", owner: "Design", due: "Tomorrow", status: "Ready" },
  { work: "Release checklist", owner: "Ops", due: "Friday", status: "Blocked" }
];

export default function DashboardApp() {
  const badgeLabel = rows.some((row) => row.status === "Blocked") ? "ACTION NEEDED" : "ON TRACK";
  return <Dashboard title="Release readiness" metrics={metrics} rows={rows} badgeLabel={badgeLabel} includeStatus />;
}
