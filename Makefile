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
	@echo "--------------------NODES--------------------"
	@kubectl get nodes
	@echo "---------------------------------------------"
	@echo "--------------------PODS---------------------"
	@kubectl get pods
	@echo "---------------------------------------------"
	@echo "-------------------SERVICE-------------------"
	@kubectl get services
	@echo "---------------------------------------------"
	@echo "------------------DEPLOYMENTS----------------"
	@kubectl get deployments
	@echo "---------------------------------------------"