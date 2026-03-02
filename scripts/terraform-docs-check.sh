#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${repo_root}/scripts/terraform-docs-generate.sh"

cd "${repo_root}"
git diff -- README.md
git diff --exit-code -- README.md

echo "terraform-docs: README is up to date"