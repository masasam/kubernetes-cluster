kubernetes: ## Init kubernetes
	yaourt kubeadm-bin
	yaourt kubelet-bin
	yaourt google-cloud-sdk
	sudo gcloud components update kubectl
	gcloud init

kubernetes-cluster: ## Kubernetes cluster setup
	gcloud container clusters create --num-nodes=2 my-cluster \
	--zone us-central-a \
	--machine-type g1-small \
	--enable-autoscaling --min-nodes=2 --max-nodes=5

kubernetes-image2gcr: ## Upload docker image to Google Container Registry
	GCP_PROJECT=$(gcloud config get-value project)
	docker build -t us.gcr.io/${GCP_PROJECT}/myapp:1.0 ${HOME}/src/github.com/masasam/myapp
	gcloud docker -- push us.gcr.io/${GCP_PROJECT}/myapp:1.0
	open https://console.cloud.google.com/gcr

kubernetes-deploy: ## Deploy myapp to kubernetes cluster
	GCP_PROJECT=$(gcloud config get-value project)
	kubectl run myapp-deploy \
	--image=us.gcr.io/${GCP_PROJECT}/myapp:1.0 \
	--replicas=1 \
	--port=3000 \
	--limits=cpu=200m \
	--command -- node app/server.js
	kubectl get pod

kubernetes-publish: ## Publish kubernetes service
	kubectl expose deployment myapp-deploy --port=80 --target-port=3000 --type=LoadBalancer
	watch kubectl get service

kubernetes-scale: ## kubernetes scale 10 pod
	kubectl scale deploy myapp-deploy --replicas=10
	watch kubectl get pod

kubernetes-rolling-update: ## Rolling update for kubernetes
	GCP_PROJECT=$(gcloud config get-value project)
	docker build -t us.gcr.io/${GCP_PROJECT}/myapp:2.0 ${HOME}/src/github.com/masasam/myapp
	gcloud docker -- push us.gcr.io/${GCP_PROJECT}/myapp:2.0
	kubectl set image deployment/myapp-deploy myapp-deploy=us.gcr.io/${GCP_PROJECT}/myapp:2.0
	watch kubectl get node

kubernetes-rollout: ## Rollout version for kubernetes
	kubectl rollout history deployment/myapp-deploy

kubernetes-delete: ## Delete kubernetes cluster
	kubectl delete deployment,service,pod --all
	gcloud container clusters delete my-cluster

kubernetes-getyaml: ## Get yaml from kubernetes server
	kubectl get deployment/myapp-deploy -o yaml --export > deploy.yaml
	kubectl get service/myapp-deploy -o yaml --export > service.yaml
	cat service.yaml | sed -e "s/clusterIP/#clusterIP/" > service.yaml

kubernetes-deploy-yaml: ## Deploy from yaml
	kubectl create -f deploy.yaml
	kubectl create -f service.yaml
	kubectl get services

kubernetes-rolling-update-yaml: ## Rolling-update from yaml
	kubectl apply -f deploy.yaml
	kubectl get pod

kubernetes-delete-yaml: ## Delete kubernetes cluster from yaml
	kubectl delete -f deploy.yaml
	kubectl delete -f service.yaml
	gcloud container clusters delete myapp-cluster

kubernetes-portforward-mariadb: ## Portforward for mariadb
	kubectl port-forward mysql-podname 3306:3306

kubernetes-mysql-dump: ## Kubernetes-portforward-mariadb next to command
	mysqldump -u root -p -h 127.0.0.1 dbname > mariadbdump

kubernetes-portforward-postgres: ## Portforward for postgres
	kubectl port-forward postgres-potname 5432:5432

kubernetes-postgres-dmup: ## Kubernetes-portforward-postgres next to command
	pg_dump -U root -h localhost dbname > pgdump

.PHONY:

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| sort \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
