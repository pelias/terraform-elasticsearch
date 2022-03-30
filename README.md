# Elasticsearch Terraform Scripts

Elasticsearch is a core part of Pelias and a complex piece of infrastructure.

There are many ways to successfully set up an Elasticsearch cluster, and many different possible sets of requirements.

This repository attempts to collect best practices for a production-ready Elasticsearch cluster run in AWS using Terraform.

## Requirements

- Terraform 0.11.x: Terraform 0.12 is [not yet supported](https://github.com/pelias/terraform-elasticsearch/issues/4)

## Compatibility

This project is compatible with Elasticsearch 7 _only_. Use historical releases
before `v7.0.0` to support Elasticsearch 5 or 6. Going forward, the major
version of this project will track the supported Elasticsearch major version.

## Setup instructions

### Create a terraform user

Terraform will need an AWS IAM user account that has permissions to create all the resources needed.

#### Set up Permissions

The Terraform user will need the `AmazonEC2FullAccess` policy attached, as well as IAM permissions.

For IAM permissions the `IAMFullAccess` policy can be used, or for more fine grained control, use this policy document:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1498231117000",
            "Effect": "Allow",
            "Action": [
                "iam:AddRoleToInstanceProfile",
                "iam:AttachRolePolicy",
                "iam:AttachUserPolicy",
                "iam:CreateRole",
                "iam:UpdateAssumeRolePolicy",
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:GetInstanceProfile",
                "iam:ListInstanceProfilesForRole",
                "iam:DeleteRole",
                "iam:GetPolicy",
                "iam:GetPolicyVersion",
                "iam:CreatePolicy",
                "iam:DetachRolePolicy",
                "iam:DeletePolicy",
                "iam:ListAttachedRolePolicies",
                "iam:ListPolicyVersions",
                "iam:DeletePolicyVersion",
                "iam:GetRole",
                "iam:PutRolePolicy",
                "iam:GetRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:PassRole"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```

#### Suggested: Set up AWS credentials file

Once the AWS user has credentials, they need to be usable.

The easiest way to use AWS credentials is to put them in `~/.aws/credentials`. This file even supports several accounts which is quite nice:

```
cat ~/.aws/credentials
[default]
aws_access_key_id = defaultKey
aws_secret_access_key = defaultSecret
region = us-east-1
output = json
[site1]
aws_access_key_id = key1
aws_secret_access_key = secret1
region = us-east-1
output = json
[site2]
aws_access_key_id     = key2
aws_secret_access_key = secret2
region = us-east-1
output = json
```

Now, different keys can be selected with `export AWS_PROFILE=site1`. Run that command before anything below and the credentials will be picked up automatically.


Once the terraform user has been set up, create an access key and keep the credentials handy for the next section

## Create Packer images

Packer images are used to avoid lengthy startup times when launching new Elasticsearch instances.

[See instructions in pelias/packer-elasticsearch](https://github.com/pelias/packer-elasticsearch)


Once the Packer images are built, they are automatically detected by the Terraform configuration.

### Set up Terraform Module configuration

While it can be run directly, this directory's code is best used as a [Terraform module](https://www.terraform.io/intro/getting-started/modules.html).

Create a file, for example `elasticsearch.tf`, with contents like the following:

```hcl
# define this once, possibly in another file if you want to run multiple clusters
provider "aws" {
  region = "us-east-1"

  version = "~> 1.60"
}

provider "template" {
  version = "~> 2.1"
}

module "elasticsearch-prod-a" {
  source = "github.com/pelias/terraform-elasticsearch?ref=v7.2.0" # check Github for the latest tagged releases

  aws_vpc_id   = "vpc-1234" # the ID of an existing VPC in which to create the instances
  ssh_key_name = "ssh-key-to-use"

  environment                       = "dev" # or whatever unique environment you choose
  elasticsearch_max_instances       = 2 # 2 r5.large instances is suitable for a minimal full-planet production build with replicas
  elasticsearch_min_instances       = 2
  elasticsearch_desired_instances   = 2
  elasticsearch_data_volume_size    = 350
  elasticsearch_instance_type       = "r5.large"
  elasticsearch_heap_memory_percent = 50
  ssh_ip_range                      = "172.20.0.0/16" # adjust this if you'd like SSH access to be limited, or remove if you don't want that
  ami_env_tag_filter                = "prod" # this variable can be adjusted if you tag your AMIs differently, or removed to use the latest AMI
  subnet_name_filter                = "us-east-*" # if you only want to launch Elasticsearch instances in some subnets, provide a filter to find the subnets. Remove if all subnets are ok
  subnet_name_filter_property       = "tag:Name" # change this if you would like to filter subnets on a tag value other than name. This can be used to create more complex selections of subnets than the prefix-matching allowed in `subnet_name_filter`

  # the following section is all optional, and if configured, will load an existing snapshot from S3 on startup
  snapshot_s3_bucket                = "name-of-your-s3-bucket" # required to load snapshot
  snapshot_base_path                = "path/to/your/snapshot"  # required to load snapshot
  #snapshot_name                     = "name-of-your-snapshot"  # optional, will load first snapshot if omitted
  snapshot_alias_name               = "pelias"                 # if you'd like an alias created, use this variable

  # you must set at least one tag as a workaround to https://github.com/pelias/terraform-elasticsearch/issues/12
  tags {
    env = "dev"
  }
}
```

Adjust any variables for your use case.


### Create Elasticsearch cluster with terraform

All that should be needed to create everything required for elasticsearch is to run the following:

```
terraform init
```

for initializing Terraform and fetching the module code, and then

```
terraform apply
```

Once that's done, it will print out the DNS name of the load balancer used to access Elasticsearch:

Here's some example output
```
Outputs:

aws_elb = internal-search-dev-elasticsearch-elb-XXXXXXXX.us-east-1.elb.amazonaws.com
```


### Add Elasticsearch Load Balancer to Kubernetes Cluster

If using this code with the [Pelias Helm chart](https://github.com/pelias/kubernetes), this section is useful.

Copy the DNS name from the Terraform output, and use it to replace the `elasticsearch.host` value in the Kubernetes chart.

Update the chart with `helm update pelias ./pelias/kubernetes -f yourValues.yaml` or similar, and new API instances with the correct settings will automatically be launched.


## Thanks

Thanks to the following sources for inspiration and code:

http://www.paulstack.co.uk/blog/2016/01/02/building-an-elasticsearch-cluster-in-aws-with-packer-and-terraform/

https://github.com/nadnerb/terraform-elasticsearch

https://github.com/floragunncom/packer-elasticsearch/blob/master/elastic.json
