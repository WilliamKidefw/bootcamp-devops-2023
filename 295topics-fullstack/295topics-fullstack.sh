#!/bin/bash

#stage 0: enviro vars
BC_PROJECT="295devops"
HOME_PROJECT="bootcamp-devops-2023"
URL_REPO="https://github.com/WilliamKidefw/bootcamp-devops-2023.git"
BRANCH_REPO="ejercicio2-dockeriza"
TAG_APP_BACKEND="295topics-backend"
TAG_APP_FRONTEND="295topics-frontend"

#stage 1: cloning the repo

if [ "$#" -eq 0 ]
then
  echo "No arguments supplied DOCKER_HUB_USERNAME and DOCKER_HUB_PASSWORD"
  exit 1
fi

DOCKER_HUB_USERNAME=$1
DOCKER_HUB_PASSWORD=$2

if [ -d $BC_PROJECT ]; then
	cd 295devops
else
	mkdir $BC_PROJECT
	cd $BC_PROJECT
fi

if [ -d $HOME_PROJECT ]; then
	cd $HOME_PROJECT
	git checkout $BRANCH_REPO
	git pull
else
	git clone $URL_REPO $HOME_PROJECT
	cd $HOME_PROJECT
	git checkout $BRANCH_REPO
fi

#stage 2: Build and Push BackEnd 295topics-fullstack
cd 295topics-fullstack

docker build -t $TAG_APP_BACKEND -f DockerFile.backend .
sleep 5

docker build -t $TAG_APP_FRONTEND -f DockerFile.frontend .
sleep 5

docker login -u $DOCKER_HUB_USERNAME -p $DOCKER_HUB_PASSWORD
sleep 5

docker tag $TAG_APP_BACKEND $DOCKER_HUB_USERNAME/$TAG_APP_BACKEND
sleep 2
docker push $DOCKER_HUB_USERNAME/$TAG_APP_BACKEND
sleep 5

docker tag $TAG_APP_FRONTEND $DOCKER_HUB_USERNAME/$TAG_APP_FRONTEND
sleep 2
docker push $DOCKER_HUB_USERNAME/$TAG_APP_FRONTEND
sleep 5

echo "DEPLOYING CONTAINERS"
sleep 2
docker-compose -f docker-compose-295topics.yml -p 295topics up -d
sleep 5
echo "THE APPLICATION IS UP AND RUNNING"
sleep 1

echo "BUILD AND PUSH script finished"
docker logout
sleep 2

sleep 60

echo "THE APPLICATION IS DESTROYING"
docker-compose -f docker-compose-295topics.yml -p 295topics down
docker rmi $TAG_APP_FRONTEND
docker rmi $TAG_APP_BACKEND
docker rmi $DOCKER_HUB_USERNAME/$TAG_APP_FRONTEND
docker rmi $DOCKER_HUB_USERNAME/$TAG_APP_BACKEND
sleep 5

echo "FINISHED"