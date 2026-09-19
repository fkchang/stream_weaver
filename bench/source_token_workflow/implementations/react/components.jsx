import React from "react";

export function Metric({ value, label }) {
  return <article className="metric"><strong className="metric-value">{value}</strong><span className="metric-label">{label}</span></article>;
}

export function Badge({ children, attention = false }) {
  return <span className={`badge${attention ? " badge--attention" : ""}`}>{children}</span>;
}

export function StatusTable({ rows, includeStatus }) {
  return (
    <div className="table-wrap">
      <table>
        <thead><tr><th>Work</th><th>Owner</th><th>Due</th>{includeStatus && <th>Status</th>}</tr></thead>
        <tbody>{rows.map((row) => <tr key={row.work}><td>{row.work}</td><td>{row.owner}</td><td>{row.due}</td>{includeStatus && <td>{row.status}</td>}</tr>)}</tbody>
      </table>
    </div>
  );
}

export function Dashboard({ title, metrics, rows, badgeLabel, includeStatus }) {
  return (
    <main className="benchmark-shell">
      <header className="benchmark-header"><h1>{title}</h1><Badge attention={badgeLabel === "ACTION NEEDED"}>{badgeLabel}</Badge></header>
      <section className="metrics" aria-label="Release metrics">{metrics.map((metric) => <Metric key={metric.label} {...metric} />)}</section>
      <StatusTable rows={rows} includeStatus={includeStatus} />
    </main>
  );
}
