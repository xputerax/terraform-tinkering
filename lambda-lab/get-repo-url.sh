#!/bin/sh

terraform show -json | jq '.values.root_module.resources[] | select(.address=="aws_ecr_repository.this") | .values.repository_url' | sed 's/"//g'