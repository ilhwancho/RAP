#!/bin/bash
# 사용: [UI5V=1.148.0] tools/ui5-fe-delete-test/go.sh <manifest.json|hide.json|anno.json>
D=$(dirname $(readlink -f $0)); M=${1:-manifest.json}; pkill -f "python fwd.py"; sleep 1
(cd $D; MAN=$M python fwd.py > fwd.log 2>&1 &)
for i in $(seq 40); do curl -s --noproxy 127.0.0.1 -o /dev/null http://127.0.0.1:8766/index.html && break; sleep 1; done
NODE_PATH=$(npm root -g) timeout 240 node $D/run.js $D/shot-$M.png; pkill -f "python fwd.py"
