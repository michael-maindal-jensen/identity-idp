# Makefile for building and running the project.
# The purpose of this Makefile is to avoid developers having to remember
# project-specific commands for building, running, etc.  Recipes longer
# than one or two lines should live in script files of their own in the
# bin/ directory.

CONFIG = config/application.yml
PORT ?= 3000

all: check

setup $(CONFIG): config/application.yml.default
	bin/setup

fast_setup:
	bin/fast_setup

docker_setup:
	bin/docker_setup

check: lint test

lint:
	@echo "--- rubocop ---"
	bundle exec rubocop
	@echo "--- slim-lint ---"
	bundle exec slim-lint app/views
	@echo "--- fasterer ---"
	bundle exec fasterer
	@echo "--- eslint ---"
	node_modules/.bin/eslint app spec

lintfix:
	@echo "--- rubocop fix ---"
	bundle exec rubocop -R -a

brakeman:
	bundle exec brakeman

test: $(CONFIG)
	RAILS_ENV=test bundle exec rake parallel:spec && yarn test

fast_test:
	bundle exec rspec --exclude-pattern "**/features/accessibility/*_spec.rb"

run:
	foreman start -p $(PORT)

load_test: $(CONFIG)
	bin/load_test $(type)

.PHONY: setup all lint run test check brakeman

normalize_yaml:
	i18n-tasks normalize
	find ./config/locales -type f | xargs ./scripts/normalize-yaml

generate_deploy_checklist:
	ruby lib/release_management/generate_deploy_checklist.rb
