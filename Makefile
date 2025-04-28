.PHONY: build coverage

build:
	forge build

coverage:
	forge coverage --report lcov --no-match-coverage "(script|mocks)"