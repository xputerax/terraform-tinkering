#!/bin/sh

docker buildx build --platform linux/amd64 \
    --provenance=false \
    -t docker-image:test \
    -t 549832005768.dkr.ecr.ap-southeast-5.amazonaws.com/sample-fn:latest \
    .
