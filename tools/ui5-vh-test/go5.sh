#!/bin/bash
D=$(dirname $(readlink -f $0)); pkill -f "^python fwd[.]py index"; sleep 1
(cd $D; python fwd.py index.html reqlog.jsonl > fwd.log 2>&1 &)
for i in $(seq 40); do curl -s --noproxy 127.0.0.1 -o /dev/null http://127.0.0.1:8765/index.html && break; sleep 1; done
cd $D/..; timeout 300 node uitest/run5.js uitest/shots $1 2>&1; pkill -f "^python fwd[.]py index"
