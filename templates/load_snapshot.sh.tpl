#!/bin/bash
set -euo pipefail


# set variables, convert terraform variables to variables used by this shell script
cluster_url="http://localhost:9200"
es_repo_name="initial_snapshot"
s3_bucket="${snapshot_s3_bucket}"
base_path="${snapshot_base_path}"
snapshot_name="${snapshot_name}"
read_only="${snapshot_repository_read_only}"
alias_name="${snapshot_alias_name}"
replica_count="${snapshot_replica_count}"
elasticsearch_delayed_allocation="${elasticsearch_delayed_allocation}"

# check all required variables are set
if [[ "$s3_bucket" == "" ]]; then
  echo "s3_bucket not set, no snapshot will be loaded"
  exit 0
fi

# Import elastic status/wait scripts
. /home/ubuntu/elastic_wait.sh

## 0. wait for elasticsearch to become ready
(elastic_wait)

# check if this node is the master node
cluster_url="http://localhost:9200"

if $(curl -s "$cluster_url/_cat/master" | grep -q `hostname`); then
  echo "this is the master node, loading snapshot"
else
  echo "this is not the master, aborting snapshot load"
  exit 0
fi

## 1. set proper settings
echo "setting optimal index recovery settings for higher performance on $cluster_url"
curl -s -XPUT --fail "$cluster_url/_cluster/settings" \
  -H 'Content-Type: application/json' \
  -d '{
  "persistent": {
    "indices.recovery.max_bytes_per_sec": "4000mb",
      "cluster.routing.allocation.node_concurrent_recoveries": 24,
      "cluster.routing.allocation.node_initial_primaries_recoveries": 24
  }
}'
echo

if [[ "${high_disk_watermark}" != "" ]]; then
  echo "setting high disk watermark to ${high_disk_watermark}"
  curl -s -XPUT --fail "$cluster_url/_cluster/settings" \
    -H 'Content-Type: application/json' \
    -d "{
      \"persistent\": {
        \"cluster.routing.allocation.disk.watermark.high\": \"${high_disk_watermark}\"
      }
    }"
fi

if [[ "${low_disk_watermark}" != "" ]]; then
  echo "setting low disk watermark to ${low_disk_watermark}"
  curl -s -XPUT --fail "$cluster_url/_cluster/settings" \
    -H 'Content-Type: application/json' \
    -d "{
      \"persistent\": {
        \"cluster.routing.allocation.disk.watermark.low\": \"${low_disk_watermark}\"
      }
    }"
fi

## 2. create snapshot repository
curl -s -XPOST --fail "$cluster_url/_snapshot/$es_repo_name" \
  -H 'Content-Type: application/json' \
  -d "{
  \"type\": \"s3\",
    \"settings\": {
      \"bucket\": \"$s3_bucket\",
      \"readonly\": $read_only,
      \"base_path\" : \"$base_path\",
      \"max_snapshot_bytes_per_sec\" : \"1000mb\",
      \"max_restore_bytes_per_sec\" : \"1000mb\"
    }
}"
echo

## 3. import snapshot

## autodetect snapshot name if not specified
if [[ "$snapshot_name" == "" ]]; then
	snapshot_name=$(curl -s -XGET --fail "$cluster_url/_snapshot/$es_repo_name/_all" | jq -r .snapshots[0].snapshot)
	echo "autodetected snapshot name is $snapshot_name"
fi

curl -s -XPOST --fail "$cluster_url/_snapshot/$es_repo_name/$snapshot_name/_restore" \
  -H 'Content-Type: application/json'

## 3.1 get first index name (excluding dot indices)
## see: https://github.com/elastic/elasticsearch/issues/50251
first_index_name=$(curl -s "$cluster_url/_cat/indices?format=json" | jq -r .[].index | grep -v '^\.')
echo "first index name is $first_index_name"

## 4. make alias if alias_name set

if [[ "$alias_name" != "" ]]; then
  echo "creating $alias_name alias pointing to $first_index_name on $cluster_url"

  curl -s -XPOST --fail "$cluster_url/_aliases" \
    -H 'Content-Type: application/json' \
    -d "{
      \"actions\": [{
        \"add\": {
          \"index\": \"$first_index_name\",
          \"alias\": \"$alias_name\"
        }
      }]
    }"
  echo
else
  echo "no alias_name set, will not create alias"
fi

## 5. set replica count
echo "setting replica count to $replica_count on $first_index_name index in $cluster_url"

curl -s -XPUT --fail "$cluster_url/$first_index_name/_settings" \
  -H 'Content-Type: application/json' \
  -d "{
  \"index\" : {
    \"number_of_replicas\" : $replica_count
  }
}"

## 6. Set index specific settings

if [[ "$elasticsearch_delayed_allocation" != "" ]]; then
  curl -s -XPUT --fail "$cluster_url/$first_index_name/_settings" \
    -H 'Content-Type: application/json' \
    -d "{
      \"settings\" : {
        \"index.unassigned.node_left.delayed_timeout\": \"$elasticsearch_delayed_allocation\"
      }
    }"
fi

echo "All done setting up Elasticsearch snapshot"
