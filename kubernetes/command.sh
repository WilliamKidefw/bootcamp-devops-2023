eval $(minikube -p minikube docker-env)
docker compose build

kubectl apply -f kubernetes/redis/db.yaml \
    -f kubernetes/redis/db-srv.yaml \
    -f kubernetes/vote/app.yaml \
    -f kubernetes/vote/app-srv.yaml \
    -f kubernetes/postgres/db.yaml \
    -f kubernetes/postgres/db-srv.yaml \
    -f kubernetes/result/app.yaml \
    -f kubernetes/result/app-srv.yaml \
    -f kubernetes/worker/app.yaml

kubectl get deploy,service,pod

kubectl describe service/redis
kubectl describe service/vote
kubectl describe service/db
kubectl describe service/result

minikube ip
curl ip:port

kubectl port-forward --address 0.0.0.0 deployment/vote 5000:80
kubectl port-forward --address 0.0.0.0 deployment/result 5001:80

kubectl logs deployment/vote
kubectl logs deployment/redis
kubectl logs deployment/postgres
kubectl logs deployment/result
kubectl logs deployment/worker

kubectl delete -f kubernetes/redis/db.yaml \
    -f kubernetes/redis/db-srv.yaml \
    -f kubernetes/vote/app.yaml \
    -f kubernetes/vote/app-srv.yaml \
    -f kubernetes/postgres/db.yaml \
    -f kubernetes/postgres/db-srv.yaml \
    -f kubernetes/result/app.yaml \
    -f kubernetes/result/app-srv.yaml \
    -f kubernetes/worker/app.yaml