## About

This repository defaults to region `ap-southeast-1` (Singapore) because `ap-southeast-5` (Malaysia) does not support function URL.

You can change it in the `terraform.tfvars` file or by passing an argument to Terraform, i.e.: `terraform apply -var="aws_region=us-east-1"`

## Variables

| variable | default | description |
|---|---|---|
| region | ap-southeast-1 | AWS region to deploy |

## Running/Deploying

```shell
# See: https://github.com/terraform-aws-modules/terraform-aws-lambda/issues/741)
export BUILDX_NO_DEFAULT_ATTESTATIONS=1
terraform init
terraform apply
```

After running, it should output the Function URL.

```text
... truncated ...
module.lambda_function.aws_lambda_function.this[0]: Creating...
module.lambda_function.aws_lambda_function.this[0]: Still creating... [00m10s elapsed]
module.lambda_function.aws_lambda_function.this[0]: Creation complete after 13s [id=sample-fn]
aws_lambda_function_url.this: Creating...
aws_lambda_function_url.this: Creation complete after 0s [id=sample-fn]

Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

function_url = "https://iqc2vhl43unase6z6ooxibwkxe0ttzdl.lambda-url.ap-southeast-1.on.aws/"
```