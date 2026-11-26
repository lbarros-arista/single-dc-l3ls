CURRENT_DIR := $(shell pwd)

.PHONY: help
help: ## Display help message
	@grep -E '^[0-9a-zA-Z_-]+\.*[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: start
start: ## Deploy ceos lab with --reconfigure flag
	sudo containerlab deploy --topo $(CURRENT_DIR)/clab/topology.clab.yml --max-workers 21 --timeout 10m --reconfigure

.PHONY: stop
stop: ## Destroy ceos lab and cleanup management network
	sudo containerlab destroy --topo $(CURRENT_DIR)/clab/topology.clab.yml --cleanup

.PHONY: clean
clean: ## Destroy ceos lab
	sudo containerlab destroy --topo $(CURRENT_DIR)/clab/topology.clab.yml --cleanup --keep-mgmt-net

.PHONY: check-lab
check-lab: ## check lab parameters
	sudo containerlab inspect --name AVD

.PHONY: build
build: ## Generate AVD configs
	cd ${CURRENT_DIR}/avd; ansible-playbook playbooks/build.yml

.PHONY: build-server-image
build-server-image: ## Build the lightweight Containerlab server image
	docker build --pull -f $(CURRENT_DIR)/server/Dockerfile -t lab-server $(CURRENT_DIR)/server

.PHONY: login-server
login-server: ## Open a shell in a server's VLAN namespace (e.g. make login-server 1a 10)
	@if [ -z "$(SERVER)" ] || [ -z "$(NS)" ]; then \
		echo "Usage: make login-server <server-suffix> <vlan> (or SERVER=<server-suffix> NS=<vlan>)"; \
		exit 2; \
	fi
	@case "$(SERVER)" in 1a|1b|2a|2b|3a|3b) ;; *) echo "Invalid SERVER='$(SERVER)'; use 1a, 1b, 2a, 2b, 3a, or 3b"; exit 2 ;; esac
	@case "$(NS)" in 10|20|30|40|50|60|70|80|90|100) ;; *) echo "Invalid NS='$(NS)'; use VLAN 10, 20, 30, 40, 50, 60, 70, 80, 90, or 100"; exit 2 ;; esac
	docker exec -it server$(SERVER) ip netns exec ns-vlan$(NS) bash

# GNU Make treats positional values after the target as additional goals.
# When login-server is requested, map those two goals to SERVER and NS, then
# provide no-op rules so Make does not try to build them as separate targets.
ifneq ($(filter login-server,$(MAKECMDGOALS)),)
LOGIN_HOST_ARGS := $(filter-out login-server,$(MAKECMDGOALS))
ifneq ($(strip $(LOGIN_HOST_ARGS)),)
ifneq ($(filter command line,$(origin SERVER) $(origin NS)),)
$(error Use either `make login-server SERVER=1a NS=10` or `make login-server 1a 10`)
endif
ifneq ($(words $(LOGIN_HOST_ARGS)),2)
$(error Usage: make login-server <server-suffix> <vlan>, e.g. make login-server 1a 10)
endif
SERVER := $(word 1,$(LOGIN_HOST_ARGS))
NS := $(word 2,$(LOGIN_HOST_ARGS))
.PHONY: $(LOGIN_HOST_ARGS)
$(LOGIN_HOST_ARGS):
	@:
endif
endif

.PHONY: deploy-eapi
deploy-eapi: ## Deploy AVD configs using eAPI
	cd ${CURRENT_DIR}/avd; ansible-playbook playbooks/deploy.yml

.PHONY: test
test: ## Test Topology
	cd ${CURRENT_DIR}/avd; ansible-playbook playbooks/anta.yml

# make test-api target COMMAND="show clock" DEVICE="dc1-spine1"
.PHONY: test-api
test-api: ## Test API to device
	curl --user ansible:ansible --data "$(COMMAND)" --insecure https://$(DEVICE):443/command-api

.PHONY: psirt
psirt: ## Create PSIRT report in Markdown Format
	cd ${CURRENT_DIR}/avd; anta psirt --inventory ./anta-inventory.yml --ignore-error --ignore-status --username admin --prompt md-report --md-output ./anta/reports/sa-report.md

.PHONY: psirt-csv
psirt-csv: ## Create PSIRT report in CSV Format
	cd ${CURRENT_DIR}/avd; anta psirt --inventory ./anta-inventory.yml --ignore-error --ignore-status --username admin --prompt csv --csv-output ./anta/reports/sa-report.csv
