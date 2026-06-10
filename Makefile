APP := Pounce
BUNDLE := $(APP).app
CONFIG := release
BIN := .build/$(CONFIG)/$(APP)
# A stable identity keeps the TCC accessibility grant across rebuilds;
# ad-hoc ("-") changes the code hash every build and invalidates it.
IDENTITY := $(shell security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/{print $$2; exit}')
ifeq ($(IDENTITY),)
IDENTITY := -
endif

.PHONY: build test bundle run clean

build:
	swift build -c $(CONFIG)

test:
	swift test

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	cp $(BIN) $(BUNDLE)/Contents/MacOS/$(APP)
	codesign --force --sign "$(IDENTITY)" $(BUNDLE)

run: bundle
	@echo "Launching $(BUNDLE) — grant Accessibility on first run, then relaunch."
	open $(BUNDLE)

clean:
	rm -rf .build $(BUNDLE)
