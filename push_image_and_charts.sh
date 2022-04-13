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
echo ${BUILD_LOCATION}

sudo docker logout
sudo docker login -u ${DTR_USER} -p  ${DTR_PASS} docker.io
if [ -n "${SERVICE_NAME}" ]; then
	cd ${BUILD_LOCATION}/${SERVICE_NAME} || eval "echo \"BUILD FAILED: ${BUILD_LOCATION}/${SERVICE_NAME} folder not found \"; exit 1"
	echo "Docker version on the build machine."
	docker version
	
	echo ${BUILD_LOCATION}/${SERVICE_NAME}
	echo "Buld number :"$SERVICE_BUILD_NUMBER
	
	if [ -n "$GIT_ID" -a -n "$JAR_FINAL_NAME" ]; then
		sudo docker build -t bmcsoftware/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER --build-arg JAR_FINAL_NAME="${JAR_FINAL_NAME}-${GIT_ID:0:7}" . || eval "echo \"BUILD FAILED: docker build failed: docker build -t bmcsoftware/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER --build-arg JAR_FINAL_NAME=${JAR_FINAL_NAME}-${GIT_ID:0:7} .\"; exit 1"
	elif [ -n "$JAR_FINAL_NAME" ]; then
		sudo docker build -t bmcsoftware/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER --build-arg JAR_FINAL_NAME="${JAR_FINAL_NAME}" . || eval "echo \"BUILD FAILED: docker build failed: docker build -t bmcsoftware/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER --build-arg JAR_FINAL_NAME=${JAR_FINAL_NAME} .\"; exit 1"
	else
		echo "For testing purpose commented this line"
		#sudo docker build -t ${DTR_IMAGE_LOCATION}/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER . || eval "echo \"BUILD FAILED: docker build failed : docker build -t vishal7/${IMAGE_NAME}:$SERVICE_BUILD_NUMBER .\"; exit 1"
	fi

	echo "Current local registry stats (On build machine) :"
	echo "For testing purpose commented this line"
	#docker images
	echo "Pushing image to private registry:"
	
	####push to DTR ##############
	echo "For testing purpose commented this line"
	#sudo docker logout
	#sleep 30
	#sudo docker login -u ${DTR_USER} -p  ${DTR_PASS} docker.io || eval "echo \"BUILD FAILED: DTR login failed \"; exit 1"
	#sudo docker push ${DTR_IMAGE_LOCATION}/$IMAGE_NAME:$SERVICE_BUILD_NUMBER ||  eval "echo \"BUILD FAILED: docker push  vishal7/$IMAGE_NAME:$SERVICE_BUILD_NUMBER failed \"; exit 1"

	#sudo docker rmi ${DTR_IMAGE_LOCATION}/$IMAGE_NAME:$SERVICE_BUILD_NUMBER || eval "echo \"BUILD FAILED: docker rmi  vishal7/$IMAGE_NAME:$SERVICE_BUILD_NUMBER failed \"; exit 1"
 fi
 
 ##################################################################################################################################################################
#								           HELM CHART
##################################################################################################################################################################
## Export helm var ####
HELM=/usr/local/bin/helm

SERVICE_BUILD_ARCHIVE_PATH="$app/$version"
BUILD_LOCATION="${ROOT_PATH_DIR}/build_dca/release/${SERVICE_BUILD_ARCHIVE_PATH}/build.${SERVICE_BUILD_NUMBER}/${SERVICE_NAME}"

if [ -z "$HELM_REPO_FOLDERS" ]
then
	HELM_REPO_FOLDERS=$SERVICE_NAME
fi


OLD_IFS=$IFS
IFS=","
for EACH_SERVICE_FOLDER in $HELM_REPO_FOLDERS
do
	echo "processing for $EACH_SERVICE_FOLDER"
	cd ${BUILD_LOCATION} || eval "echo \"BUILD FAILED: ${BUILD_LOCATION} folder not found \"; exit 1"
	IFS=$OLD_IFS
	if [ -f "devops/helm-chart/$EACH_SERVICE_FOLDER/Chart.yaml" ]
	then
		echo "
		###########################################################################
		# Starting Helm Module
		###########################################################################
		"

		REGISTRY_HOST=`echo "${DTR_IMAGE_LOCATION}" | cut -d"/" -f1`
		ORG=`echo "${DTR_IMAGE_LOCATION}" | cut -d"/" -f2-`
		sudo sed -i -e "s/__chart_version__/$SERVICE_BUILD_NUMBER/g" \
			-e "s/__release_version__/$RELEASE_VERSION/g" \
			-e "s/__service_name__/$EACH_SERVICE_FOLDER/g" devops/helm-chart/$EACH_SERVICE_FOLDER/Chart.yaml
		
		sudo sed -i -e "s/__chart_version__/$SERVICE_BUILD_NUMBER/g" \
			-e "s/__registryhost__/$REGISTRY_HOST/g" \
			-e "s/__service_name__/$EACH_SERVICE_FOLDER/g" \
			-e "s/__image_name__/$IMAGE_NAME/g" \
			-e "s%__org__%$ORG%g" devops/helm-chart/$EACH_SERVICE_FOLDER/values.yaml

		for EACH_TEMPLATE in devops/helm-chart/$EACH_SERVICE_FOLDER/templates/*.yaml
		do
			sudo sed -i -e "s/__service_name__/$EACH_SERVICE_FOLDER/g" $EACH_TEMPLATE
		done

		logexe cd devops/helm-chart/$EACH_SERVICE_FOLDER
		logexe sudo $HELM dependency update
		cd ..
		logexe sudo $HELM template $EACH_SERVICE_FOLDER
		if [ $? -ne 0 ]
		then
			echo "BUILD FAILED: Invalid helm charts"
			exit 1
		fi
	fi
done

if [ -d ${BUILD_LOCATION}/helmtest ]; then
	sudo rm -rf ${BUILD_LOCATION}/helmtest
fi
logexe sudo mkdir -p ${BUILD_LOCATION}/helmtest
logexe cd ${BUILD_LOCATION}/helmtest
echo "
###########################################################################
# Initiating GIT push
###########################################################################
"

logexe sudo git clone https://github.com/vishalhassanandani/ADE-ade-helm-chart.git --depth 1
i_RETURN=0
OLD_IFS=$IFS
IFS=","
for EACH_SERVICE_FOLDER in $HELM_REPO_FOLDERS
do
	echo "pushing helm for $EACH_SERVICE_FOLDER"
	IFS=$OLD_IFS
	logexe cd ${BUILD_LOCATION}
	if [ -f devops/helm-chart/$EACH_SERVICE_FOLDER/Chart.yaml ]
	then
		sudo $HELM package devops/helm-chart/$EACH_SERVICE_FOLDER/

		APP_NAME=$(egrep "^name: .*"  devops/helm-chart/$EACH_SERVICE_FOLDER/Chart.yaml | sed -e "s/^name: \(.*\)/\1/" -e 's/^"//' -e 's/"$//')
		if [ ! -d "${BUILD_LOCATION}/helmtest/${CHART_REPO}" ]; then
			sudo mkdir -p ${BUILD_LOCATION}/helmtest/${CHART_REPO}/
		fi
		logexe sudo cp ${BUILD_LOCATION}/${APP_NAME}-$SERVICE_BUILD_NUMBER.tgz  ${BUILD_LOCATION}/helmtest/${CHART_REPO}/
		logexe sudo cp ${BUILD_LOCATION}/${APP_NAME}-$SERVICE_BUILD_NUMBER.tgz  ${BUILD_LOCATION}/devops/
		cd ${BUILD_LOCATION}/helmtest/${CHART_REPO}/ || exit 1

		sudo $HELM repo index .
		logexe sudo git add ${BUILD_LOCATION}/helmtest/${CHART_REPO}/${APP_NAME}-$SERVICE_BUILD_NUMBER.tgz
		logexe sudo git add ${BUILD_LOCATION}/helmtest/${CHART_REPO}/index.yaml
		GIT_COMMIT="true"

	fi
done
if [ "$GIT_COMMIT" = "true" ]
then
	logexe sudo git commit -m "from $version"
	logexe sudo git pull -u origin master
	logexe sudo git push -u origin master
	i_RETURN=$?
	if [ $i_RETURN -ne 0 ]; then
		logexe sudo git pull -u origin master
		logexe sudo git push -u origin master
		i_RETURN=$?
	fi
fi

sudo rm -rf ${BUILD_LOCATION}/helmtest
if [ $i_RETURN -ne 0 ]; then
	exit $i_RETURN
fi
