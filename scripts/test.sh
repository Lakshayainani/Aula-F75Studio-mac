#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/f75-tests.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT
swiftc Sources/F75Core/*.swift Tests/F75CoreTests/*.swift -o "$check_dir/protocol-tests"
"$check_dir/protocol-tests" Tests/Fixtures/protocol-frames.json
