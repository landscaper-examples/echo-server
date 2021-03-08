NAME                        := echo-server
COMPONENT                   := github.com/landscaper-examples/echo-server
QUALIFIER                   := dev
RELEASE                     := false
REGISTRY                    := ghcr.io/
IMAGEORG                    := landscaper-examples
IMAGE_PREFIX                := $(REGISTRY)$(IMAGEORG)
IMAGE                       := $(IMAGE_PREFIX)/$(NAME)
HELM_CHART_REF              := $(IMAGE_PREFIX)/helm/$(NAME)
REPOSITORY_CONTEXT          := $(IMAGE_PREFIX)
REPO_ROOT                   := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
VERSION                     := $(shell cat "$(REPO_ROOT)/VERSION")
COMMIT                      := $(shell git rev-parse HEAD)
ifeq ($(QUALIFIER),)
VERSINFO                    := $(VERSION)-$(COMMIT)
else
VERSINFO                    := $(VERSION)-$(QUALIFIER)-$(COMMIT)
endif
ifeq ($(RELEASE),true)
IMAGE_TAG                   := $(VERSION)
else
ifeq ($(QUALIFIER),)
IMAGE_TAG                   := $(VERSION)
else
IMAGE_TAG                   := $(VERSION)-$(QUALIFIER)-$(COMMIT)
endif
endif
VERSION_VAR                 := main.version
LD_FLAGS                    := -ldflags "-X $(VERSION_VAR)=$(VERSINFO)"

.PHONY: build
build:
	@echo QUALIFIER=$(QUALIFIER)
	@echo RELEASE=$(RELEASE)
	GO_ENABLED=0 GOOS=$(go env GOOS) GOARCH=$(go env GOARCH) GO111MODULE=on go install \
      $(LD_FLAGS) \
	  ./cmd/echo-server

.PHONY: image
image:
	docker build -t $(IMAGE):$(IMAGE_TAG) -t $(IMAGE_PREFIX)/$(NAME):latest -f Dockerfile -m 6g --build-arg QUALIFIER=$(QUALIFIER) --build-arg RELEASE=$(RELEASE) .

.PHONY: image-release
image-release:
	docker build -t $(IMAGE):$(VERSION) -t $(IMAGE_PREFIX)/$(NAME):latest -f Dockerfile -m 6g --build-arg QUALIFIER= --build-arg RELEASE=true .

.PHONY: image-push
image-push: image
	docker push $(IMAGE):$(IMAGE_TAG)

.PHONY: image-push-release
image-push-release: image-release
	docker push $(IMAGE):$(VERSION)

.PHONY: helm
helm:
	HELM_EXPERIMENTAL_OCI=1 helm chart save ./chart $(HELM_CHART_REF):$(VERSION)

.PHONY: helm-push
helm-push: helm
	HELM_EXPERIMENTAL_OCI=1 helm chart push $(HELM_CHART_REF):$(VERSION)

component: image cd

.PHONY: cd
cd: clean
	component-cli ca resource add -v=5 --component-name $(COMPONENT)  --component-version $(IMAGE_TAG) gen/ctf/component resources.yaml \
		IMAGE=$(IMAGE) \
		HELM_CHART_REF=$(HELM_CHART_REF) \
		IMAGE_TAG=$(IMAGE_TAG)

.PHONY: ctf
ctf: cd
	component-cli ctf add gen/component.ctf -f gen/ctf/component
export: component ctf

.PHONY: ctf-upload
ctf-upload: ctf
	component-cli ctf push gen/component.ctf --repo-ctx=$(REPOSITORY_CONTEXT)

.PHONY: build-all
build-all: image-push helm-push ctf

.PHONY: all
all: image-push helm-push ctf-upload

clean:
	rm -rf gen