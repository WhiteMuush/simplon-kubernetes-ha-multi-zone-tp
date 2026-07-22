CLUSTER:=kind-config

.PHONY: create-cluster
create-cluster :
	@kind create cluster --config $(CLUSTER).yaml
	@echo "---------------------------------------------"

.PHONY: delete-cluster
delete-cluster :
	@kind delete cluster --name $(CLUSTER)
	@echo "---------------------------------------------"

.PHONY: status-cluster
status-cluster :
	@echo "--------------------NODES ET ZONES--------------------"
	@kubectl get nodes -o custom-columns='NODE:.metadata.name,ZONE:.metadata.labels.zone,STATUS:.status.conditions[-1:].type,INTERNAL-IP:.status.addresses[?(@.type=="InternalIP")].address,EXTERNAL-IP:.status.addresses[?(@.type=="ExternalIP")].address'
	@echo "---------------------------------------------"
	@echo "--------------------PODS STATUS------------"
	@kubectl get pods -o wide
	@echo "---------------------------------------------"
	@echo "-------------------SERVICE-------------------"
	@kubectl get services
	@echo "---------------------------------------------"
	@echo "------------------DEPLOYMENTS----------------"
	@kubectl get deployments
	@echo "---------------------------------------------"