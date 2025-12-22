#!/usr/bin/env bash

docker images --format "table {{.Repository}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | uniq
