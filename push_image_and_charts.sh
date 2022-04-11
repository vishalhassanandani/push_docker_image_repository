#!/bin/bash

git config --global push.default simple

#set -x

cstr_SPACE='[[:space:]]'
trim()
{
	sed -e "s/^$cstr_SPACE*//" -e "s/$cstr_SPACE*$//"
}

#these are mandatory parameters
# app="dem"
# version="ci_dem_feature_flag_service_build"
# SERVICE_BUILD_NUMBER="DEV1587"
# SERVICE_NAME="featureflag-service"
# IMAGE_NAME="truesight-featureflag-service"
# CHART_REPO="ade-chart-repository/cloudops"
# JAR_FINAL_NAME=truesight-resource-service-1.0.0
# GIT_ID=${GIT_COMMIT}
# DTR_IMAGE_LOCATION="phx-epddtr-prd.bmc.com/bmc_qa/lpcs5"
# HELM_REPO_FOLDERS="multiple helm folders, comma separated values, no space in between" 

app=$(echo "$app" | trim)
version=$(echo "$version" | trim)
SERVICE_BUILD_NUMBER=$(echo "$SERVICE_BUILD_NUMBER" | trim)
SERVICE_NAME=$(echo "$SERVICE_NAME" | trim)
IMAGE_NAME=$(echo "$IMAGE_NAME" | trim)
CHART_REPO=$(echo "$CHART_REPO" | trim)
JAR_FINAL_NAME=$(echo "$JAR_FINAL_NAME" | trim)
GIT_ID=$(echo "$GIT_ID" | trim)
DTR_IMAGE_LOCATION=$(echo "$DTR_IMAGE_LOCATION" | trim)
HELM_REPO_FOLDERS=$(echo "$HELM_REPO_FOLDERS" | trim)

## Export helm var ####
DEVKITS_DIR=/build/devkits
HELM=$DEVKITS_DIR/tools/build_software/helm/3.2.1/helm3

## Print Input Varibels ##
echo ${app}
echo ${version}
echo ${SERVICE_BUILD_NUMBER}
echo ${SERVICE_NAME}
echo ${IMAGE_NAME}
echo ${CHART_REPO}
echo ${JAR_FINAL_NAME}
echo ${GIT_ID}
echo ${DTR_IMAGE_LOCATION}
echo ${HELM_REPO_FOLDERS}

logexe()
{
  echo '['`date +%y%m%d-%H%M%S`'][CMD]' "$@"
  "$@"
}

CURRENT_USER=`whoami`; export CURRENT_USER
if [ ${CURRENT_USER} == "root" ]; then
   ROOT_PATH_DIR=/build2; export ROOT_PATH_DIR
else
   ROOT_PATH_DIR=/build1; export ROOT_PATH_DIR
fi
if [ -z "$HELM_REPO_FOLDERS" ]
then
	HELM_REPO_FOLDERS=$SERVICE_NAME
fi

# if [ -z "$SERVICE_NAME" ];then
	# echo "SERVICE_NAME is null skipping build"
	# exit 0
# fi

if [ -z "$DTR_IMAGE_LOCATION" ];then
	echo "BUILD FAILED: variable DTR_IMAGE_LOCATION is must"
	exit 1
fi

SERVICE_BUILD_ARCHIVE_PATH="$app/$version"
BUILD_LOCATION="${ROOT_PATH_DIR}/build_dca/release/${SERVICE_BUILD_ARCHIVE_PATH}/build.${SERVICE_BUILD_NUMBER}"

echo 'Archive path is ${SERVICE_BUILD_ARCHIVE_PATH}'
echo 'Build Location is ${BUILD_LOCATION}'
echo 'DTR IMAGE LOCATION is ${DTR_IMAGE_LOCATION}'


if [ -n "${SERVICE_NAME}" ]; then
	cd ${BUILD_LOCATION}/${SERVICE_NAME} || eval "echo \"BUILD FAILED: ${BUILD_LOCATION}/${SERVICE_NAME} folder not found \"; exit 1"
	echo "Docker version on the build machine."
	docker version

	echo "Buld number :"$SERVICE_BUILD_NUMBER
	if [ -n "$GIT_ID" -a -n "$JAR_FINAL_NAME" ]; then
		docker build -t bmcsoftware/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER --build-arg JAR_FINAL_NAME="${JAR_FINAL_NAME}-${GIT_ID:0:7}" . || eval "echo \"BUILD FAILED: docker build failed: docker build -t bmcsoftware/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER --build-arg JAR_FINAL_NAME=${JAR_FINAL_NAME}-${GIT_ID:0:7} .\"; exit 1"
	elif [ -n "$JAR_FINAL_NAME" ]; then
		docker build -t bmcsoftware/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER --build-arg JAR_FINAL_NAME="${JAR_FINAL_NAME}" . || eval "echo \"BUILD FAILED: docker build failed: docker build -t bmcsoftware/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER --build-arg JAR_FINAL_NAME=${JAR_FINAL_NAME} .\"; exit 1"
	else
		docker build -t vishal7/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER . || eval "echo \"BUILD FAILED: docker build failed : docker build -t bmcsoftware/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER .\"; exit 1"
	fi

	echo "Current local registry stats (On build machine) :"
	docker images
	echo "Pushing image to private registry:"
	docker version
	if [ "$DTR_ONLY" != "true" ]; then
		docker login -u ${BMC_PRIVATE_DOCKERHUB_USER} -p  ${BMC_PRIVATE_DOCKERHUB_PASS} || eval "echo \"BUILD FAILED: Docker login failed \"; exit 1"
		docker push bmcsoftware/$IMAGE_NAME:$SERVICE_BUILD_NUMBER || eval "echo \"BUILD FAILED: docker push failed \"; docker rmi bmcsoftware/$IMAGE_NAME:$SERVICE_BUILD_NUMBER; exit 1"
		# docker rmi bmcsoftware/$IMAGE_NAME:$SERVICE_BUILD_NUMBER
	fi


	####push to DTR ##############

	docker login /index.docker.io/v1/ -u ${DTR_USER} -p  ${DTR_PASS} || eval "docker rmi vishal7/$IMAGE_NAME:$SERVICE_BUILD_NUMBER; echo \"BUILD FAILED: DTR login failed \"; exit 1"
	docker tag vishal7/$IMAGE_NAME:$SERVICE_BUILD_NUMBER ${DTR_IMAGE_LOCATION}:${IMAGE_NAME}-$SERVICE_BUILD_NUMBER || eval "echo \"BUILD FAILED: docker tag failed \"; exit 1"
	docker push ${DTR_IMAGE_LOCATION}:${IMAGE_NAME}-$SERVICE_BUILD_NUMBER || eval "docker rmi ${DTR_IMAGE_LOCATION}:${IMAGE_NAME}-$SERVICE_BUILD_NUMBER; docker rmi vishal7/$IMAGE_NAME:$SERVICE_BUILD_NUMBER; echo \"BUILD FAILED: DTR push failed \"; exit 1"
	docker rmi ${DTR_IMAGE_LOCATION}:${IMAGE_NAME}-$SERVICE_BUILD_NUMBER || eval "docker rmi vishal7/$IMAGE_NAME:$SERVICE_BUILD_NUMBER; echo \"BUILD FAILED: docker rmi ${DTR_IMAGE_LOCATION}:${IMAGE_NAME}-$SERVICE_BUILD_NUMBER failed \"; exit 1"


	docker rmi bmcsoftware/$IMAGE_NAME:$SERVICE_BUILD_NUMBER || eval "echo \"BUILD FAILED: docker rmi  bmcsoftware/$IMAGE_NAME:$SERVICE_BUILD_NUMBER failed \"; exit 1"
 f1
