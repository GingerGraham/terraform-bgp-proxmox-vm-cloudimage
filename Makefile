.PHONY: docs docs-check

docs:
	./scripts/terraform-docs-generate.sh

docs-check:
	./scripts/terraform-docs-check.sh
