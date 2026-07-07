# Elastic Container Service (ECS) Lab

## About

Elastic Container Service (ECS) Lab. This deploys a service `echo-server-service` which contains the [ealen/echo-server](https://hub.docker.com/r/ealen/echo-server) container.

Verify communication between ALB/EC2:

```bash
curl http://<lb-dns-name>
```

Output:

```text
<h1>Hello from ip-10-10-10-201.ap-southeast-5.compute.internal</h1>
```

Verify communication between ALB/ECS Service:

```bash
curl http://<lb-dns-name>/echo
```

Output:

```text
curl -s "ecs-lb-1578488677.ap-southeast-5.elb.amazonaws.com/echo/some/path?param=1" | jq

{
  "host": {
    "hostname": "ecs-lb-1578488677.ap-southeast-5.elb.amazonaws.com",
    "ip": "::ffff:10.10.10.52",
    "ips": []
  },
  ... truncated ...
}
```

## Running/Deploying

```bash
terraform init
terraform apply
```

Sample Output:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

bastion_instance_id = "i-0828fffb1f785693b"
bastion_private_ip = "10.10.10.155"
lb_url = "ecs-lb-1578488677.ap-southeast-5.elb.amazonaws.com"
nat_ips = tolist([
  "56.68.32.144",
  "56.69.23.19",
])
node_launchtemplate_version = 1
```