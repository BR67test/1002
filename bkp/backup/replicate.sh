#!/bin/bash
rsync -avz --delete \
    -e "ssh -i /root/.ssh/replication_key" \
    /srv/borg/repo/ \
    borgbackup@10.0.10.12:/srv/borg/repo/
