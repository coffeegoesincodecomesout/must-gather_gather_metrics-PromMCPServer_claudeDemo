# Prometheus Must-Gather MCP Demo

## Context

This session is connected to a **historical Prometheus dataset**, not a live cluster. The data was collected from an OpenShift cluster using `oc adm must-gather -- gather_metrics` and converted into TSDB blocks. The Prometheus instance serves this frozen snapshot.

**Critical implication:** `now()` is outside the data's time range. Instant queries using the current timestamp will return no data. You must discover the data's time range and anchor all queries to timestamps within it.

## Mandatory Workflow

Follow this sequence for every investigation:

1. **Check health** — call `health_check` to confirm the Prometheus instance is reachable.
2. **Discover the time range** — use `execute_range_query` with a 30-day lookback (e.g. start=now-30d, end=now, step=1h) to find where data actually exists. Must-gather dumps are typically collected within the last 7–14 days.
3. **List metrics** — call `list_metrics` before querying anything. Never assume a metric name exists; always verify.
4. **Get metadata** — use `get_metric_metadata` to understand labels and dimensions before filtering.
5. **Query with correct timestamps** — use timestamps from within the discovered data window. Prefer `execute_range_query` over instant queries for historical data exploration.

## Key Rules

- **Never query a metric without first calling `list_metrics`.** Metric names in must-gather dumps reflect the specific OpenShift version and configuration of the source cluster.
- **Always use explicit timestamps.** Do not rely on relative time expressions like "5 minutes ago" without first anchoring to the data's actual time range.
- **Prefer range queries.** They are more useful for historical data than instant queries, which require an exact timestamp within the data window.
- **The data is from an OpenShift cluster.** Metrics follow Kubernetes/OpenShift naming conventions (e.g. `kube_*`, `node_*`, `etcd_*`, `apiserver_*`).

## Available Services

| Service    | URL                    | Purpose                              |
|------------|------------------------|--------------------------------------|
| Prometheus | http://localhost:9090  | Query historical metrics via MCP tools |
| Perses     | http://localhost:8080  | Dashboard creation and visualization |

## Perses Dashboards

A Perses instance is running with pre-provisioned dashboards. You can create new dashboards in Perses using the Perses API or by generating dashboard YAML. When asked to visualize data, prefer creating a Perses dashboard over describing results as text.
