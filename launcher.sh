#!/bin/bash

MODEL_API="https://claude--apicast-production.apps.int.stc.ai.prod.us-east-1.aws.paas.redhat.com:443"
MODEL_ID="claude-sonnet-4@20250514"
PROXY_PORT="8787"

#Clean up
mkdir -p tmp/

if ! test -f firstrun.txt;
  then
    rm -rf tmp/*
    #Install claude?
    read -p "This demo requires a claude code subscription - do you want to install claude?" -n 1 -r
      echo
        if [[ $REPLY =~ ^[Yy]$ ]]
          then
            curl -fsSL https://claude.ai/install.sh | bash
        fi

    #Add Prometheus MCP server to Claude
    read -p "This demo uses a Prometheus MCP server - do you want to install it?" -n 1 -r
      echo
        if [[ $REPLY =~ ^[Yy]$ ]]
          then
            claude mcp add prometheus --env PROMETHEUS_URL=http://localhost:9090 -- podman run -i --rm --network=host -e PROMETHEUS_URL ghcr.io/pab1it0/prometheus-mcp-server:latest
        fi

    #Get desired PROM_VERSION
      echo -n "Insert desired Prometheus version - Match this to the version of the cluster that created the dump. Openshift 4.18 uses '2.51.1' :"
      read PROM_VERSION

    #Get API user key for internal Claude model
      echo -n "Enter your models.corp USER_KEY (application credential): "
      read -s USER_KEY
      echo

      echo "PROM_VERSION=$PROM_VERSION" > firstrun.txt
      echo "USER_KEY=$USER_KEY" >> firstrun.txt

    #Download the desired PROM_VERSION
      curl -Ls https://github.com/prometheus/prometheus/releases/download/v$PROM_VERSION/prometheus-$PROM_VERSION.linux-amd64.tar.gz | tar -xvz -C tmp
       touch firstrun.txt
fi

source firstrun.txt
echo $PROM_VERSION

#Build the API proxy if not already built
if ! test -f api-proxy/api-proxy; then
  echo "building API proxy..."
  go build -o api-proxy/api-proxy ./api-proxy/
fi

#Create configfiles
echo "creating config files..."
mkdir -p tmp/prometheus-config
touch tmp/prometheus-config/prometheus.yml

#Create tsdb blocks from openmetrics
echo "creating TSDB block..."
tmp/prometheus-$PROM_VERSION.linux-amd64/promtool tsdb create-blocks-from openmetrics must-gather.local.*/quay-io-openshift-*/monitoring/metrics/metrics.openmetrics tmp/prometheus-$PROM_VERSION.linux-amd64/data/

#Start the API proxy in the background
echo "starting API proxy on port $PROXY_PORT..."
MODEL_API=$MODEL_API MODEL_ID=$MODEL_ID USER_KEY=$USER_KEY PROXY_PORT=$PROXY_PORT api-proxy/api-proxy &
PROXY_PID=$!
trap "kill $PROXY_PID 2>/dev/null" EXIT

#Launch the Prometheus container in the background
echo "launching the Prometheus instance..."
podman run --rm -p 9090:9090/tcp -v $PWD/tmp/prometheus-$PROM_VERSION.linux-amd64/data:/prometheus:U,Z --privileged quay.io/prometheus/prometheus:v$PROM_VERSION --storage.tsdb.path=/prometheus --config.file=/dev/null &
PROM_PID=$!
trap "kill $PROXY_PID $PROM_PID 2>/dev/null" EXIT

#Launch Claude Code pointed at the internal API via the local proxy
echo "launching Claude Code..."
ANTHROPIC_BASE_URL="http://127.0.0.1:$PROXY_PORT" \
ANTHROPIC_API_KEY="internal" \
ANTHROPIC_MODEL="$MODEL_ID" \
  claude
