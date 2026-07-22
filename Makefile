CLUSTER1:=francecentral-1
CLUSTER2:=francecentral-2
CLUSTER3:=francecentral-3

.PHONY: create-clusters
create-clusters :
	@kind create cluster --config $(CLUSTER1).yaml
	@echo "------------------------------------------------"
	@kind create cluster --config $(CLUSTER2).yaml
	@echo "------------------------------------------------"
	@kind create cluster --config $(CLUSTER3).yaml
	@echo "------------------------------------------------"

.PHONY: delete-clusters
delete-clusters :
	@kind delete cluster --name $(CLUSTER1)
	@echo "------------------------------------------------"
	@kind delete cluster --name $(CLUSTER2)
	@echo "------------------------------------------------"
	@kind delete cluster --name $(CLUSTER3)
	@echo "------------------------------------------------"