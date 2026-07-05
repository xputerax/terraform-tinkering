#!/bin/sh

docker run --rm -p 9000:8080 \
    --entrypoint /usr/local/bin/aws-lambda-rie \
    docker-image:test ./main