#!/usr/bin/env bash

sudo snapper -c root list

echo ""
echo "Take a snapshot:"
echo "sudo snapper -c root create -d \"SNAPSHOT_DESCRIPTION\""
echo ""
echo "Delete snapshot(s):"
echo "sudo snapper -c root delete --sync <SNAPSHOT_NUMBER>"
echo ""
