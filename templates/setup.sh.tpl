#!/bin/bash
set -e

# get list of IPs for this ASG to bootstrap Elasticsearch cluster

function join_by { local IFS="$1"; shift; echo "$*"; }

region=$(curl -s 169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
this_instance_id=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)

asg_name=$(aws autoscaling describe-auto-scaling-instances --region $region --output text --instance-ids $this_instance_id \
        --query "AutoScalingInstances[0].AutoScalingGroupName")

instance_ids=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $asg_name --output text --region $region \
        --query "AutoScalingGroups[0].Instances[].InstanceId")

instance_ips=$(echo $instance_ids | xargs -n1 aws ec2 describe-instances --instance-ids $ID --region $region \
        --query "Reservations[].Instances[].PrivateIpAddress" --output text)

asg_ip_list=$(join_by , $instance_ips)

# Generate elasticsearch.yml

cat <<EOF >/etc/elasticsearch/elasticsearch.yml
cluster.name: ${es_cluster_name}
cluster.routing.allocation.awareness.attributes: ${allocation_awareness_attributes}

node.name: $${HOSTNAME} # the $${HOSTNAME} var is filled in by Elasticsearch

# our init.d script sets the default to this as well
path.data: ${elasticsearch_data_dir}
path.logs: ${elasticsearch_log_dir}

# enable memory locking
bootstrap.memory_lock: true

network.host: [ '_ec2:privateIpv4_', _local_ ]
network.publish_host: '_ec2:privateIpv4_'
discovery.seed_providers: ec2
discovery.ec2.groups: ${aws_security_group}
discovery.ec2.availability_zones: [${availability_zones}]
discovery.ec2.endpoint: ec2.$${region}.amazonaws.com

cluster.initial_master_nodes: [ $asg_ip_list ]

cloud.node.auto_attributes: true

gateway.recover_after_time: 5m
gateway.recover_after_nodes: ${expected_nodes}
gateway.expected_data_nodes: ${expected_nodes}

# circuit breakers
indices.breaker.fielddata.limit: ${elasticsearch_fielddata_limit}
EOF

## set search queue size if set
if [[ "${elasticsearch_search_queue_size}" != "" ]]; then
  echo "thread_pool.search.queue_size: ${elasticsearch_search_queue_size}" >> /etc/elasticsearch/elasticsearch.yml
fi

# elasticsearch 2.4 specific settings
# note: we can check if 'bin/plugin' exists, this was renamed after 2.4
if [ -f '/usr/share/elasticsearch/bin/plugin' ]; then
  # in older versions of ES 'memory_lock' is called 'mlockall'
  sed -i 's/bootstrap.memory_lock/bootstrap.mlockall/g' /etc/elasticsearch/elasticsearch.yml
fi

# heap size
memory_in_bytes=`awk '/MemTotal/ {print $2}' /proc/meminfo`
heap_memory=$(( memory_in_bytes * ${elasticsearch_heap_memory_percent} / 100 / 1024 )) # take percentage of system memory, and convert to MB

# Make sure we're not over 31GB
max_memory=31000
if [[ "$heap_memory" -gt "$max_memory" ]]; then
  heap_memory="$max_memory"
fi

sudo sed -i 's/#\?MAX_LOCKED_MEMORY=.*/MAX_LOCKED_MEMORY=unlimited/' /etc/init.d/elasticsearch
sudo sed -i "s/-Xms.*/-Xms$${heap_memory}m/" /etc/elasticsearch/jvm.options
sudo sed -i "s/-Xmx.*/-Xmx$${heap_memory}m/" /etc/elasticsearch/jvm.options

# data volume
data_volume_name="/dev/sdb" # default to an EBS volume mapped to /dev/sdb

# check for local NVMe disks and use them if found
potential_nvme_disk="$(ls /dev/disk/by-id/nvme-Amazon_EC2_NVMe_Instance_Storage* | head -1)"
if [[ "$potential_nvme_disk" != "" ]]; then
  echo "using local NVMe disk at $potential_nvme_disk"
  data_volume_name=$potential_nvme_disk
fi

sudo mkfs -t ext4 $data_volume_name
sudo tune2fs -m 0 $data_volume_name
sudo mkdir -p ${elasticsearch_data_dir}
sudo mount $data_volume_name ${elasticsearch_data_dir}
sudo echo "$data_volume_name ${elasticsearch_data_dir} ext4 defaults,nofail 0 2" >> /etc/fstab
sudo chown -R elasticsearch:elasticsearch ${elasticsearch_data_dir}

# log volume
log_volume_name="/dev/sdc"
sudo mkfs -t ext4 $log_volume_name
sudo tune2fs -m 0 $log_volume_name
sudo mkdir -p ${elasticsearch_log_dir}
sudo mount $log_volume_name ${elasticsearch_log_dir}
sudo echo "$log_volume_name ${elasticsearch_log_dir} ext4 defaults,nofail 0 2" >> /etc/fstab
sudo chown -R elasticsearch:elasticsearch ${elasticsearch_log_dir}

# set LimitMEMLOCK for systemd (required for memory locking to work with systemd)
# https://www.elastic.co/guide/en/elasticsearch/reference/master/setting-system-settings.html
if [ "$(ps --no-headers -o comm 1)" = 'systemd' ]; then
  sudo mkdir -p /usr/lib/systemd/system/elasticsearch.service.d
  sudo echo -e '[Service]\nLimitMEMLOCK=infinity' > /usr/lib/systemd/system/elasticsearch.service.d/override.conf
  sudo systemctl daemon-reload
fi

# Start Elasticsearch
sudo service elasticsearch start

# Ensure Elasticsearch restarts after reboot
sudo systemctl enable elasticsearch

# Import elastic status/wait scripts
. /home/ubuntu/elastic_wait.sh

# Wait for elasticsearch service to come up (note elastic_wait exits 0|1); then
# Put index template
# These settings will be automatically merged when creating new indices.
# Since elasticsearch v5+ this is now the recommended way to set node-specific settings.
# https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-templates.html
# Since elasticsearch v6+ the 'template' param was renamed 'index_patterns'.
# https://github.com/pelias/terraform-elasticsearch/issues/9
# https://www.elastic.co/guide/en/elasticsearch/reference/6.2/breaking_60_indices_changes.html
(elastic_wait) && curl \
  -X PUT \
  --fail \
  -H 'Content-Type: application/json' \
  -d '{
    "template": ["pelias*"],
    "index_patterns": ["pelias*"],
    "order": 0,
    "settings": {
      "search.slowlog.threshold.query.warn": "5s",
      "search.slowlog.threshold.query.info": "1s",
      "search.slowlog.threshold.fetch.warn": "5s",
      "indexing.slowlog.threshold.index.info": "10s"
    }
  }' \
  'localhost:9200/_template/pelias_global_settings'
