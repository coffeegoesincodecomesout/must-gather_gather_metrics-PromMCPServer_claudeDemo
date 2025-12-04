# must-gather_gather_metrics-PromMCPServer_claudeDemo

This repo demonstrates extracting selected metrics from an Openshift cluster.
The exported metrics are used to create TSDB blocks and expose that data via a containized prometheus instance.
Claude is then used to query the data via a Prometheus MCP server. 

`oc adm must-gather` can now collect metrics from a given cluster
This feature is available from 4.18 + 

```
oc adm must-gather -- gather_metrics \
--min-time=$(date --date='2 hours ago' +%s%3N) \
--match="{__name__=~\'kube_node_.*\'}"
```

Run the must-gather command within this repo or place a pre collected `must-gather -- gather_metrics` directory into the root of this repo.


Running the launcher will result in the collected data being available via a running container

```
./launcher.sh
```

launch claude and configure the MCP server.
Tell Claude that is its querying a Prometheus dump containing historical data:
```
I see! The Prometheus server contains historical data from a promdump. Let me query with a proper timestamp. I'll calculate 1 hour ago:
```

Now you can query the data using natural language:

```
● Great! Found the nodes with master role from 1 hour ago:

  3 Master Nodes:

  1. sharedocp420-sxt45-master-0
  2. sharedocp420-sxt45-master-1
  3. sharedocp420-sxt45-master-2
```

This script touches the file `firstrun.txt` after its firstrun. 
