MDBOOK_VERSION ?= 0.4.37
MDBOOK_BIN_VERSION ?= v$(MDBOOK_VERSION)
SOURCE_PATH := docs/user-guide
CONTAINER_RUNTIME ?= sudo docker
IMAGE_NAME := quay.io/metal3-io/mdbook
IMAGE_TAG ?= latest
HOST_PORT ?= 3000
MDBOOK_RELEASE_URL := https://github.com/rust-lang/mdBook/releases/download/$(MDBOOK_BIN_VERSION)/mdbook-$(MDBOOK_BIN_VERSION)-x86_64-unknown-linux-gnu.tar.gz
TOOLS_DIR := hack/tools
TOOLS_BIN_DIR := $(abspath $(TOOLS_DIR)/bin)
MDBOOK_BIN := $(TOOLS_BIN_DIR)/mdbook

export PATH := $(PATH):$(TOOLS_BIN_DIR)

## ------------------------------------
## Resolve placeholders as tags
## ------------------------------------
RELEASETAGS := $(TOOLS_BIN_DIR)/mdbook-releasetags
$(RELEASETAGS): $(TOOLS_DIR)/go.mod
	cd $(TOOLS_DIR); go build -tags=tools -o $(TOOLS_BIN_DIR)/mdbook-releasetags ./releasetags

.PHONY: releasetags
releasetags: $(RELEASETAGS)

## ------------------------------------
## Documentation tooling for Netlify
## ------------------------------------

# This binary is used by Netlify. Because,
# Netlify build image doesn't support docker/podman.

$(MDBOOK_BIN): # Download the binary
	curl -L $(MDBOOK_RELEASE_URL) | tar xvz -C $(TOOLS_BIN_DIR)

.PHONY: netlify-build
netlify-build: $(RELEASETAGS) $(MDBOOK_BIN)
	$(MDBOOK_BIN) build $(SOURCE_PATH)


## ------------------------------------
## Documentation tooling for local dev
## ------------------------------------

.PHONY: build
docker-build: # Build the mdbook container image
	$(CONTAINER_RUNTIME) build --build-arg MDBOOK_VERSION=$(MDBOOK_VERSION) \
	--tag $(IMAGE_NAME):$(IMAGE_TAG) -f docs/Dockerfile .

.PHONY: build
build:# Build the user guide
	$(CONTAINER_RUNTIME) run \
	--rm -it --name metal3 \
	-v "$$(pwd):/workdir" \
	$(IMAGE_NAME):$(IMAGE_TAG) \
	mdbook build $(SOURCE_PATH)

.PHONY: serve
serve:# Serve the user-guide on localhost:3000 (by default)
	$(CONTAINER_RUNTIME) run \
	--rm -it --init --name metal3 \
	-v "$$(pwd):/workdir" \
	-p $(HOST_PORT):3000 \
	$(IMAGE_NAME):$(IMAGE_TAG) \
	mdbook serve --open $(SOURCE_PATH) -p 3000 -n 0.0.0.0

.PHONY: clean
clean: # Clean mdbook generated content
	$(CONTAINER_RUNTIME) run \
	--rm -it --name metal3 \
	-v "$$(pwd):/workdir" \
	$(IMAGE_NAME):$(IMAGE_TAG) \
	mdbook clean $(SOURCE_PATH)

## ------------------------------------
## Linting and testing
## ------------------------------------

.PHONY: lint
lint: markdownlint spellcheck shellcheck # Run all linting tools

.PHONY: markdownlint
markdownlint: # Run markdownlint
	./hack/markdownlint.sh

.PHONY: spellcheck
spellcheck: # Run spellcheck
	./hack/spellcheck.sh

.PHONY: shellcheck
shellcheck: # Run shellcheck
	./hack/shellcheck.sh
