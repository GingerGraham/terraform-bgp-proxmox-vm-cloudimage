#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

podman run --rm \
  -v "${repo_root}:/terraform-docs:Z" \
  -w /terraform-docs \
  quay.io/terraform-docs/terraform-docs:latest \
  markdown table --config /terraform-docs/.terraform-docs.yml .

echo "terraform-docs: README updated in ${repo_root}"