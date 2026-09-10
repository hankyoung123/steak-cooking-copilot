# Developer entry points for the steak copilot.
#
# Config/production.yaml is the single source of truth for tunable parameters:
# `make tuning` regenerates the Swift artifact, `make check-tuning` verifies it
# (this is what CI runs before xcodebuild).

PROJECT := SteakCopilot.xcodeproj
SCHEME := SteakCopilot
DERIVED := .derivedData/dev
DESTINATION := platform=iOS Simulator,name=iPhone 17

.PHONY: help tuning check-tuning self-test build test-unit test-ui test clean

help:
	@echo "make tuning        Regenerate ProductionTuning.generated.swift from production.yaml"
	@echo "make check-tuning  Fail if the generated artifact is stale (CI parity)"
	@echo "make self-test     Validate the generator offline (parser + validation cases)"
	@echo "make build         Compile the app and test bundles"
	@echo "make test-unit     Run unit tests"
	@echo "make test-ui       Run UI tests"
	@echo "make test          Run the full suite"

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
