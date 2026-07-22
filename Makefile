CLUSTERFILE:=kind-config.yaml
CLUSTERNAME:=francecentral

.PHONY: create-cluster
create-cluster :
	@echo "--------------creating cluster---------------"
	@kind create cluster --config $(CLUSTERFILE)
	@echo "---------------------------------------------"
	@echo "----------Loading image in cluster-----------"
	@kind load docker-image microservices:1.0 -n $(CLUSTERNAME)
	@echo "---------------------------------------------"

.PHONY: delete-cluster
delete-cluster :
	@kind delete cluster --name $(CLUSTERNAME)
	@echo "---------------------------------------------"

.PHONY: status-cluster
status-cluster :
	@echo "--------------------NODES--------------------"
	@kubectl get nodes -o custom-columns='NODE:.metadata.name,ZONE:.metadata.labels.zone,STATUS:.status.conditions[-1:].type,INTERNAL-IP:.status.addresses[?(@.type=="InternalIP")].address,EXTERNAL-IP:.status.addresses[?(@.type=="ExternalIP")].address'
	@echo "---------------------------------------------"
	@echo "--------------------PODS---------------------"
	@kubectl get pods -o wide
	@echo "---------------------------------------------"
	@echo "-------------------SERVICE-------------------"
	@kubectl get services
	@echo "---------------------------------------------"
	@echo "------------------DEPLOYMENTS----------------"
	@kubectl get deployments
	@echo "---------------------------------------------"

.PHONY: deployments
deployments:
	@echo "----------------api deployment---------------"
	@kubectl apply -f ./k8s/api/api-deployment.yaml
	@echo "---------------------------------------------"
	@echo "---------------books deployment--------------"
	@kubectl apply -f ./k8s/books/books-deployment.yaml
	@echo "---------------------------------------------"
	@echo "---------------movies deployment-------------"
	@kubectl apply -f ./k8s/movies/movies-deployment.yaml
	@echo "---------------------------------------------"

.PHONY: services
services:
	@echo "-----------------api service-----------------"
	@kubectl apply -f ./k8s/api/api-service.yaml
	@echo "---------------------------------------------"
	@echo "----------------books service----------------"
	@kubectl apply -f ./k8s/books/books-service.yaml
	@echo "---------------------------------------------"
	@echo "----------------movies service---------------"
	@kubectl apply -f ./k8s/movies/movies-service.yaml
	@echo "---------------------------------------------"
