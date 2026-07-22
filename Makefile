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
	@kubectl get nodes
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
