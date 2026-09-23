PACKAGE := qluels-nvim
REVISION := 1

CURRENT_ROCKSPEC := $(wildcard $(PACKAGE)-*-$(REVISION).rockspec)
CURRENT_VERSION := $(patsubst $(PACKAGE)-%-$(REVISION).rockspec,%,$(CURRENT_ROCKSPEC))

.PHONY: bump-major bump-minor bump-patch

bump-major bump-minor bump-patch: bump-%:
	@if [ -z "$(CURRENT_ROCKSPEC)" ]; then \
		echo "error: no rockspec found"; exit 1; \
	fi
	@NEW_VERSION=$$(semver bump $* $(CURRENT_VERSION)); \
	NEW_ROCKSPEC="$(PACKAGE)-$$NEW_VERSION-$(REVISION).rockspec"; \
	sed "s/version = \"$(CURRENT_VERSION)-$(REVISION)\"/version = \"$$NEW_VERSION-$(REVISION)\"/" \
		"$(CURRENT_ROCKSPEC)" > "$$NEW_ROCKSPEC"; \
	rm "$(CURRENT_ROCKSPEC)"; \
	echo "$(CURRENT_VERSION) -> $$NEW_VERSION ($$NEW_ROCKSPEC)"
