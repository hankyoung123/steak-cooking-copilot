# Developer entry points for the steak copilot.
#
# Config/production.yaml is the single source of truth for tunable parameters:
# `make tuning` regenerates the Swift artifact, `make check-tuning` verifies it
# (this is what CI runs before xcodebuild).

PROJECT := SteakCopilot.xcodeproj
SCHEME := SteakCopilot
DERIVED := .derivedData/dev
# UI tests run on one device only: geometry regressions are device-independent,
# and the per-device coverage that does matter (every supported container height)
# lives in SessionLayoutMetricsTests, which is far cheaper than a UI walk.
DESTINATION := platform=iOS Simulator,name=iPhone 17

# The only UI tests that need to run while iterating on layout.
LAYOUT_UI_TESTS := \
	-only-testing:SteakCopilotUITests/SteakCopilotUITests/testHomeSkeletonSlotsDoNotMoveBetweenCuts \
	-only-testing:SteakCopilotUITests/SteakCopilotUITests/testSessionSkeletonSlotsDoNotMoveBetweenCookingPhases \
	-only-testing:SteakCopilotUITests/SteakCopilotUITests/testResultSkeletonSlotsDoNotMoveBetweenReadyEatFeedback

.PHONY: help tuning check-tuning self-test build test-unit test-ui test-ui-layout test clean

help:
	@echo "make tuning          Regenerate ProductionTuning.generated.swift from production.yaml"
	@echo "make check-tuning    Fail if the generated artifact is stale (CI parity)"
	@echo "make self-test       Validate the generator offline (parser + validation cases)"
	@echo "make build           Compile the app and test bundles"
	@echo "make test-unit       Run unit tests"
	@echo "make test-ui-layout  Run only the layout skeleton UI regression tests (one device)"
	@echo "make test-ui         Run the full UI suite (one device, broad runs only)"
	@echo "make test            Run the full suite"

tuning:
	python3 Scripts/generate_tuning.py

check-tuning:
	python3 Scripts/generate_tuning.py --self-test
	python3 Scripts/generate_tuning.py --check

self-test:
	python3 Scripts/generate_tuning.py --self-test

build:
	xcodebuild build-for-testing \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		CODE_SIGNING_ALLOWED=NO

test-unit:
	xcodebuild test-without-building \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		-only-testing:SteakCopilotTests \
		CODE_SIGNING_ALLOWED=NO

test-ui-layout:
	xcodebuild test-without-building \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		$(LAYOUT_UI_TESTS) \
		CODE_SIGNING_ALLOWED=NO

test-ui:
	xcodebuild test-without-building \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		-only-testing:SteakCopilotUITests \
		CODE_SIGNING_ALLOWED=NO

test:
	xcodebuild test \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		CODE_SIGNING_ALLOWED=NO

clean:
	rm -rf $(DERIVED)
