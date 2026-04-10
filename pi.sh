#!/bin/sh

set -euxo pipefail

nixos-rebuild --flake .#plan-ai-pi --build-host $(id -un)@aarch64.plan.ai --target-host root@200:7ef6:32c6:540a:d4:3e52:6e1c:fdd9 switch
