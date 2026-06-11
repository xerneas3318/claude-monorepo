.PHONY: help install dev relay sync ios lint clean ios-build doctor

help:
	@echo "claude-monorepo targets:"
	@echo "  make install   - npm install for relay + sync-daemon"
	@echo "  make dev       - run relay + sync-daemon in parallel (foreground)"
	@echo "  make relay     - run relay only"
	@echo "  make sync      - run sync-daemon only"
	@echo "  make ios       - regenerate Xcode project from project.yml and open it"
	@echo "  make ios-build - xcodebuild the iOS app (Debug, Simulator)"
	@echo "  make lint      - placeholder for linters per app"
	@echo "  make clean     - remove node_modules and Xcode DerivedData"
	@echo "  make doctor    - check required tools are installed"

install:
	cd apps/relay && npm install
	cd apps/sync-daemon && npm install

dev:
	@( cd apps/relay && npm run dev 2>&1 | sed 's/^/[relay] /' ) & \
	  ( cd apps/sync-daemon && npm start 2>&1 | sed 's/^/[sync ] /' ) & \
	  wait

relay:
	cd apps/relay && npm run dev

sync:
	cd apps/sync-daemon && npm start

ios:
	cd apps/ios-app && ./bootstrap.sh
	open apps/ios-app/ClaudePlanner.xcodeproj

ios-build:
	cd apps/ios-app && ./bootstrap.sh
	xcodebuild -project apps/ios-app/ClaudePlanner.xcodeproj \
	  -scheme ClaudePlanner \
	  -destination 'generic/platform=iOS Simulator' \
	  -configuration Debug build

lint:
	@echo "TODO: add eslint configs in apps/relay and apps/sync-daemon"
	@echo "      Swift: swiftlint or swiftformat (not configured yet)"

clean:
	rm -rf apps/relay/node_modules apps/sync-daemon/node_modules
	rm -rf apps/ios-app/build apps/ios-app/DerivedData
	find . -name '.DS_Store' -delete
	@echo "cleaned."

doctor:
	@command -v node >/dev/null    && echo "node:      $$(node -v)"      || echo "node:      MISSING"
	@command -v npm  >/dev/null    && echo "npm:       $$(npm -v)"       || echo "npm:       MISSING"
	@command -v xcodegen >/dev/null && echo "xcodegen:  $$(xcodegen --version 2>&1 | tail -n1)" || echo "xcodegen:  MISSING (brew install xcodegen)"
	@command -v xcodebuild >/dev/null && echo "xcodebuild: present"      || echo "xcodebuild: MISSING (install Xcode)"
	@command -v git >/dev/null && echo "git:       $$(git --version | awk '{print $$3}')" || echo "git: MISSING"
