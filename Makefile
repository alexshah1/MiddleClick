all: archive export compress

APP_NAME := MiddleClickPlus
APP_BUNDLE_ID := com.alexander.MiddleClickPlus
APP_PATH := /Applications/$(APP_NAME).app

## Development targets
.PHONY: run force-build install-local package-local reset-accessibility clean-build

# Find all source files to track dependencies
SOURCES := $(shell find MiddleClick MoreTouch ConfigCore -type f \( -name "*.swift" -o -name "*.h" -o -name "*.m" \) 2>/dev/null)

# Stamp file to track last build
BUILD_STAMP := ./build/.build-stamp

# Only build if sources changed since last build
$(BUILD_STAMP): $(SOURCES)
	@echo "🔨 Building MiddleClick (Debug)..."
	xcodebuild -project MiddleClick.xcodeproj -scheme MiddleClick -configuration Debug build
	@echo "✅ Build succeeded!"
	@mkdir -p $(dir $(BUILD_STAMP))
	@touch $(BUILD_STAMP)

build-debug: $(BUILD_STAMP)

run: $(BUILD_STAMP)
	@echo "🚀 Running MiddleClick..."
	@BUILD_SKIP=1 ./scripts/build-and-run.sh

force-build:
	@rm -f $(BUILD_STAMP)
	@$(MAKE) build-debug

install-local: force-build
	@BUILT_PRODUCTS_DIR=$$(xcodebuild -project MiddleClick.xcodeproj -scheme MiddleClick -configuration Debug -showBuildSettings 2>/dev/null | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p' | tail -1); \
	BUILT_APP_PATH="$$BUILT_PRODUCTS_DIR/$(APP_NAME).app"; \
	if [ ! -d "$$BUILT_APP_PATH" ]; then \
		echo "❌ Missing built app at $$BUILT_APP_PATH"; \
		exit 1; \
	fi; \
	echo "📦 Installing $$BUILT_APP_PATH to $(APP_PATH)"; \
	pkill -x $(APP_NAME) 2>/dev/null || true; \
	ditto "$$BUILT_APP_PATH" "$(APP_PATH)"; \
	defaults write $(APP_BUNDLE_ID) fingers 3; \
	defaults write $(APP_BUNDLE_ID) mediaPlayPauseFingers 4; \
	open "$(APP_PATH)"; \
	echo "✅ Installed and launched $(APP_NAME)"

package-local: force-build
	@BUILT_PRODUCTS_DIR=$$(xcodebuild -project MiddleClick.xcodeproj -scheme MiddleClick -configuration Debug -showBuildSettings 2>/dev/null | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p' | tail -1); \
	BUILT_APP_PATH="$$BUILT_PRODUCTS_DIR/$(APP_NAME).app"; \
	if [ ! -d "$$BUILT_APP_PATH" ]; then \
		echo "❌ Missing built app at $$BUILT_APP_PATH"; \
		exit 1; \
	fi; \
	mkdir -p build; \
	rm -f build/$(APP_NAME)-local.zip; \
	ditto -c -k --keepParent "$$BUILT_APP_PATH" build/$(APP_NAME)-local.zip; \
	echo "✅ Created build/$(APP_NAME)-local.zip"

reset-accessibility:
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@tccutil reset Accessibility $(APP_BUNDLE_ID)
	@open "$(APP_PATH)" || true
	@echo "Open System Settings → Privacy & Security → Accessibility, then enable MiddleClick+."

clean-build:
	@rm -f $(BUILD_STAMP)
	@echo "🧹 Build stamp cleaned"

## Release targets
archive:
	xcodebuild -project MiddleClick.xcodeproj -scheme MiddleClick -configuration Release archive

export:
	xcodebuild -exportArchive \
		-archivePath "$(shell ls -td ~/Library/Developer/Xcode/Archives/*/MiddleClick*.xcarchive | head -1)" \
		-exportPath "$(shell pwd)/build" \
		-exportOptionsPlist ./build-config/ExportOptions.plist

compress:
	cd ./build && \
	rm -f ./$(APP_NAME).zip && \
	zip -r9 ./$(APP_NAME).zip ./$(APP_NAME).app

create-cert:
	security export -k ~/Library/Keychains/login.keychain-db -t identities -f pkcs12 | base64 | pbcopy
