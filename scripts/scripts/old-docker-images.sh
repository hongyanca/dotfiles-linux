#!/usr/bin/env bash

# This script shortens the output of 'docker images --digests'
# It truncates the sha256 digest to the first 8 characters and adjusts formatting.

# Check if the command output is piped or if we should run the command ourselves
if [ -t 0 ]; then
  # No pipe, run the command
  INPUT_CMD="docker images --digests"
else
  # Data is being piped in
  INPUT_CMD="cat"
fi

$INPUT_CMD | awk '
BEGIN {
    # Print the header with adjusted spacing
    printf "%-30s %-12s %-16s %-12s %-16s %s\n", "REPOSITORY", "TAG", "DIGEST", "IMAGE ID", "CREATED", "SIZE"
}
NR > 1 {
    # $3 is the DIGEST column (sha256:...)
    # Shorten sha256:xxxxxxxx... to sha256:xxxxxxxx (15 chars total)
    short_digest = substr($3, 1, 15)

    # Reconstruct the "CREATED" string which might span multiple columns ($5, $6, $7)
    # This part handles "12 minutes ago", "5 days ago", etc.
    created = ""
    for (i=5; i<NF; i++) {
        created = created $i " "
    }

    # $NF is the last column (SIZE)
    size = $NF

    # Print formatted row
    printf "%-30s %-12s %-16s %-12s %-16s %s\n", $1, $2, short_digest, $4, created, size
}'
