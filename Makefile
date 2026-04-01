APP_NAME := VoicePi
BUILD_DIR := .build
DIST_DIR := dist

DEBUG_BIN_DIR := $(shell swift build --show-bin-path)
RELEASE_BIN_DIR := $(shell swift build -c release --show-bin-path)

APP_BUNDLE := $(DIST_DIR)/release/$(APP_NAME).app
DEBUG_APP_BUNDLE := $(DIST_DIR)/debug/$(APP_NAME).app
EXECUTABLE := $(RELEASE_BIN_DIR)/$(APP_NAME)
DEBUG_EXECUTABLE := $(DEBUG_BIN_DIR)/$(APP_NAME)

INFO_PLIST := Sources/VoicePi/Info.plist
ENTITLEMENTS := Sources/VoicePi/VoicePi.entitlements
APP_ICONSET := Sources/VoicePi/AppIcon.appiconset
APP_ICON_FILE := AppIcon
SIGN_IDENTITY ?= -
INSTALL_DIR ?= /Applications
APP_ID ?= com.voicepi.app

.PHONY: all build verify package run install clean bundle debug release dist-clean

all: verify

build: verify

verify: debug
	@echo "Verification bundle ready: $(DEBUG_APP_BUNDLE)"

package: verify release
	@echo "Packaged app bundle ready: $(APP_BUNDLE)"

debug:
	@echo "==> Running verification build"
	swift build
	@$(MAKE) bundle APP_DIR="$(DEBUG_APP_BUNDLE)" EXEC="$(DEBUG_EXECUTABLE)"
	@echo "Built app bundle: $(DEBUG_APP_BUNDLE)"

release:
	@echo "==> Running release packaging build"
	swift build -c release
	@$(MAKE) bundle APP_DIR="$(APP_BUNDLE)" EXEC="$(EXECUTABLE)"
	@echo "Built app bundle: $(APP_BUNDLE)"

bundle:
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	cp "$(EXEC)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp "$(INFO_PLIST)" "$(APP_DIR)/Contents/Info.plist"
	if [ -d "$(APP_ICONSET)" ]; then \
		TMP_ICONSET_DIR=$$(mktemp -d "$${TMPDIR:-/tmp}/voicepi-iconset.XXXXXX.iconset"); \
		trap 'rm -rf "$$TMP_ICONSET_DIR"' EXIT INT TERM; \
		cp "$(APP_ICONSET)/icon_16.png" "$$TMP_ICONSET_DIR/icon_16x16.png"; \
		cp "$(APP_ICONSET)/icon_32.png" "$$TMP_ICONSET_DIR/icon_16x16@2x.png"; \
		cp "$(APP_ICONSET)/icon_32.png" "$$TMP_ICONSET_DIR/icon_32x32.png"; \
		cp "$(APP_ICONSET)/icon_64.png" "$$TMP_ICONSET_DIR/icon_32x32@2x.png"; \
		cp "$(APP_ICONSET)/icon_128.png" "$$TMP_ICONSET_DIR/icon_128x128.png"; \
		cp "$(APP_ICONSET)/icon_256.png" "$$TMP_ICONSET_DIR/icon_128x128@2x.png"; \
		cp "$(APP_ICONSET)/icon_256.png" "$$TMP_ICONSET_DIR/icon_256x256.png"; \
		cp "$(APP_ICONSET)/icon_512.png" "$$TMP_ICONSET_DIR/icon_256x256@2x.png"; \
		cp "$(APP_ICONSET)/icon_512.png" "$$TMP_ICONSET_DIR/icon_512x512.png"; \
		cp "$(APP_ICONSET)/icon_1024.png" "$$TMP_ICONSET_DIR/icon_512x512@2x.png"; \
		iconutil --convert icns "$$TMP_ICONSET_DIR" --output "$(APP_DIR)/Contents/Resources/$(APP_ICON_FILE).icns"; \
		rm -rf "$$TMP_ICONSET_DIR"; \
	fi
	if [ -f "$(ENTITLEMENTS)" ]; then \
		codesign --force --sign "$(SIGN_IDENTITY)" --entitlements "$(ENTITLEMENTS)" --options runtime "$(APP_DIR)"; \
	else \
		codesign --force --deep --sign "$(SIGN_IDENTITY)" "$(APP_DIR)"; \
	fi

run: verify
	open "$(DEBUG_APP_BUNDLE)"

install: package
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf "$(BUILD_DIR)"

dist-clean:
	rm -rf "$(DIST_DIR)"
