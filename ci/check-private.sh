#!/bin/sh
# Refuses a `private` submodule pointer that moved backwards (or sideways)
# between BASE (default: the parent commit) and HEAD (or the second argument): an older private drops
# secrets services need (see .agents/rules/submodules.md).
set -eu
base=${1:-HEAD~1}
head=${2:-HEAD}
old=$(git ls-tree "$base" private | awk '{print $3}')
new=$(git ls-tree "$head" private | awk '{print $3}')
if [ -z "$old" ] || [ "$old" = "$new" ]; then
  echo "private: unchanged"
  exit 0
fi
git submodule update --init private >/dev/null 2>&1 || true
git -C private fetch -q origin
if git -C private merge-base --is-ancestor "$old" "$new"; then
  echo "private: $old -> $new (forward)"
  exit 0
fi
echo "private: $old -> $new is NOT forward: an older or unrelated revision was committed." >&2
echo "Restore it: git -C private checkout $old && git add private" >&2
exit 1
