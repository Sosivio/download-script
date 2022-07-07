#!/bin/bash

# ------------------------ #

## Notes for clients:
# Please make sure you have sudo permissions on local machine.

# ------------------------ #

# Env vars:
declare -a microServices

# dev-collector sosiviodb dash as testing. 

version=release-1.4.1.1
microServices=("analyzer" "authentication" "actuator" "classifier" "crud-manager" "contract-testing" "communicator" "sosivio-node-collector" "sosivio-node-pinger" "correlation-entities" "draingo" "nsq" "sosivio-dashboard" "sequence-recognition" "discovery-engine" "sosiviodb" "notifier" "prediction-engine")
ourDockerRepo="release.sosiv.io"
userName="customer"           # Client default user
password="customer"           # Client default user password
requiredTarSpace=18           # Disk space needed on the computer from which script is ran
requiredImageSpace=12         # Disk space needed for pulling the docker images
directoryName="SosivioImages" # Directory where the docker images will be saved
OS="`uname`"                  # This determines the type of Operating System

function Usage() {
    echo "Sosivio-download-script manual:

Usage: sosivio-download-script --pull|--push [OPTIONS]

Options:
    --registryPath=   Directory path in container registry where Sosivio images will be saved. (only used with '--push').
    -h ,--help        Show help menu.
    --pull            Pulling Sosivio images and tar them. (is required if '--push' is not used)
    --push            Pushing Sosivio images to registry. (is required if '--pull' is not used)
    --registry=       Container registry DNS. (only used with '--push').
    --tarName=        Name for tar file with container images. (default is 'SosivioImages.tar.gz' in current directory)

Requirements:
    For pulling images: - connection to the internet and at least $requiredImageSpace GB of free disk space.
    For pushing images: - $requiredTarSpace GB of free disk space on the computer from which this script is running
                        - $requiredImageSpace GB free space in client\'s docker image registry.
"
exit 0
}


function CheckForValue() {
    if [ -z $1 ]; then
        echo "Variable is empty please enter value."
        Usage
    fi
}

################################################  MAIN starts here  ################################################

if [ $# -eq 0 ]; then
    echo -e "\nNo arguments entered. Must specificy --pull or --push.\n"
    Usage
else
    for arg in "$@";
    do
        case $arg in
            -h|--help)
            Usage
            shift
            ;;
            --pull)
            if [ -z $flag ]; then
                flag="pull"
            fi
            shift
            ;;
            --push)
            if [ -z $flag ]; then
                flag="push"
            fi
            shift
            ;;
            --registry=*)
            if [ -z $clientRegistry ]; then
                clientRegistry=${1#*=}
            fi
            shift
            ;;
            --registryPath=*)
            if [ -z $clientRegistryPath ]; then
                clientRegistryPath=${1#*=}
            fi
            shift
            ;;
            --tarName=*)
            if [ -z $tarName ]; then
                tarName=${1#*=}
            fi
            shift
            ;;
            *)
            shift
            ;;
        esac
    done
fi

if [ -z $flag ]; then
    echo "Missing --pull or --push flag."
    Usage
elif [ $flag == "push" ]; then
    if [ -z $clientRegistry ]; then
        read -p "Please enter your registry DNS to which the images are going to be pushed to (--registry): " clientRegistry
        CheckForValue $clientRegistry

    fi
    if [ -z $clientRegistryPath ]; then
        read -p "Please enter path in the registry, where the images are going to be saved (--registryPath): " clientRegistryPath
        CheckForValue $clientRegistryPath
    fi
fi

if [ -z $tarName ]; then
    tarName=$directoryName.tar.gz
fi

sudo bash -c "docker --help > /dev/null"
exitCode=$?
if [ $exitCode -eq 0 ]; then
    echo ""
elif [ $exitCode -eq 127  ]; then
    echo "Docker is not installed on this machine."
    exit $exitCode
else
    echo "There is a problem with your Docker cli.\nPlease re-install it or check sudo permissions."
    exit $exitCode
fi

if [ $OS == "Linux" ]; then

    ## -----------------------------  Pulling  ------------------------------ ##

    if [ $flag == "pull" ]; then
        sudo docker login $ourDockerRepo -u $userName -p $password
        exitCode=$?
        if [ $exitCode -ne 0 ]; then
            echo "There is a problem reaching the Sosivio registry. Check your internet connection."
            exit 1
        fi
        # check docker storage space before pulling
        dockerpath=$(sudo docker info | grep 'Docker Root Dir' | awk -F ' ' '{print $4}')
        spaceleft=$(sudo df -h $dockerpath | tail -n -1  | awk '{print $4}'| tr -d G)
        if [ $spaceleft -lt $requiredImageSpace ]; then
            echo "You do not have enough space in Docker ($dockerpath) to download all of Sosivio images."
            exit 126
        fi

        echo -e "\nPulling Images...\n"
        for i in "${microServices[@]}";
        do
            sudo docker pull $ourDockerRepo/$i:$version
        done

        spaceleft=$(sudo df -h $(pwd) | tail -n -1  | awk '{print $4}'| tr -d G)
        if [ $spaceleft -lt $requiredTarSpace ]; then
            echo "Cannot tar images' in $(pwd). Filesystem has less disk space than required."
            exit 126
        else
            if [ -d $(pwd)/$directoryName ]; then
                echo -e "\nDirectory \"$directoryName\" already exist. Exiting.\n"
                exit 1
            else
                echo -e "\nCreating Directory $directoryName in $(pwd)"
                sudo mkdir $(pwd)/$directoryName
                sudo chmod o+xrw $(pwd)/$directoryName
                echo -e "Directory successfully created: $(pwd)/$directoryName \n"
            fi

            echo -e "Saving Images...\n"
            for i in "${microServices[@]}";
            do
                echo "Saving image $i"
                sudo docker save $ourDockerRepo/$i:$version > $(pwd)/$directoryName/$i.tar #TODO: put this on /tmp instead plain to client eyes ???
            done
          echo -e "\nCompressing Images...\n"
          sudo tar cvzf $(pwd)/$tarName $directoryName/*
    	    echo -e "\nPlease copy \"$tarName\" to the disconnected environment to continue the process."
          sudo rm -rf SosivioImages
        fi

    ## ------------------------- Pushing ---------------------------##

    elif [ $flag == "push" ]; then
        read -p "Enter user name to login to your registry: (\"$clientRegistry\") " userName
        echo "sudo docker login $clientRegistry -u $userName "
        exitCode=$?
        if [ $exitCode -ne 0 ]; then
            echo "There is a problem reaching the registry: \"$clientRegistry\"."
            exit 1
        fi
        # checking that the tar has enough space in the client's OS.
        spaceleft=$(sudo df -h $(pwd) | tail -n -1  | awk '{print $4}'| tr -d G)
        if [ $spaceleft -lt $requiredTarSpace ]; then
            echo "You do not have enough space in Docker ($dockerpath) to download all of Sosivio images."
            exit 126
        fi
        echo -e "Extracting images...\n"
        sudo tar -xvf $tarName
        exitCode=$?
        if [ $exitCode -ne 0 ]; then
            echo "Error during decompressing tar."
        fi
        dockerpath=$(sudo docker info | grep 'Docker Root Dir' | awk -F ' ' '{print $4}')
        spaceleft=$(sudo df -h $dockerpath | tail -n -1  | awk '{print $4}'| tr -d G)
        if [ $spaceleft -lt  $requiredImageSpace ]; then
            echo "You do not have enough space in Docker ($dockerpath) to 'docker save' all of Sosivio's images."
            exit 126
        fi

        if [ -d $(pwd)/$directoryName ]; then
            echo "Found \"$directoryName\" in current directory."
        else
            echo "Did not find \"$directoryName\" in current directory."
            exit 1
        fi

        for i in $(ls $directoryName );
        do
            sudo docker load -q -i $(pwd)/$directoryName/$i
        done
        exitCode=$?
        if [ $exitCode -ne 0 ]; then
            echo "Something went wrong with \"sudo docker load\" command."
            exit $exitCode
        fi
        # Finally pushing the images to the client's registry.

        echo -e "Tagging and Pushing Images...\n"
        for i in "${microServices[@]}";
        do
            echo "Tagging image $i"
            sudo docker tag $ourDockerRepo/$i:$version $clientRegistry/$clientRegistryPath/$i:$version
            echo "Pushing image $i"
            sudo docker push $clientRegistry/$clientRegistryPath/$i:$version
        done
    else
        echo "The values for flags are not correct"
        exit 1
    fi

elif [ $OS == "Darwin" ]; then

    ## -----------------------------  Pulling  ------------------------------ ##

    if [ $flag == "pull" ]; then
        sudo docker login $ourDockerRepo -u $userName -p $password
        exitCode=$?
        if [ $exitCode -ne 0 ]; then
            echo "There is a problem reaching the Sosivio registry. Check your internet connection."
            exit 1
        fi

        totalDockerSpace=$(ls -klsh ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw | awk '{print $6}' | tr -d G)
        usedDockerSpace=$(du -h ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw | awk '{print $1}' | tr -d G)
        spaceleft=$(($totalDockerSpace-$usedDockerSpace))

        if [[ $spaceleft -lt $requiredImageSpace ]]; then
            echo "You do not have enough space in Docker ($dockerpath) to download all of Sosivio images."
            exit 126
        fi

        echo -e "Pulling Images...\n"
        for i in "${microServices[@]}";
        do
            sudo docker pull $ourDockerRepo/$i:$version
        done

        spaceleft=$(sudo df -h $(pwd) | tail -n -1  | awk '{print $4}'| tr -d Gi)
        if [[ $spaceleft -lt $requiredTarSpace ]]; then
            echo "You do not have enough space in Docker ($dockerpath) to download all of Sosivio images."
            exit 126
        else
            if [ -d $(pwd)/$directoryName ]; then
                echo -e "\nDirectory \"$directoryName\" already exist. Exiting\n"
                exit 1
            else
                echo -e "\nCreating Directory $directoryName in $(pwd)"
                sudo mkdir $(pwd)/$directoryName
                sudo chmod 777 $(pwd)/$directoryName
                echo -e "Directory successfully created: $(pwd)/$directoryName \n"
            fi

            echo -e "Saving Images...\n"
            for i in "${microServices[@]}";
            do
                echo "saving image $i"
                sudo docker save $ourDockerRepo/$i:$version > $(pwd)/$directoryName/$i.tar
            done
          echo -e "\nCompressing Images...\n"
          sudo tar cvzf $(pwd)/$tarName $directoryName/*
    	    echo -e "\nPlease copy the file \"$tarName\" to the disconnected environment to continue the process."
          sudo rm -rf SosivioImages
        fi

    ## ------------------------- Pushing ---------------------------##

    elif [ $flag == "push" ]; then
        read -p "Enter your docker registry username: (\"$clientRegistry\") " userName
        sudo docker login $clientRegistry -u $userName
        exitCode=$?
        if [ $exitCode -ne 0 ]; then
            echo "There is a problem reaching the registry: \"$clientRegistry\"."
            exit 1
        fi

        spaceleft=$(sudo df -h $(pwd) | tail -n -1  | awk '{print $4}'| tr -d Gi)
        if [[ $spaceleft -lt $requiredTarSpace ]]; then
            echo "Cannot tar images' in $(pwd). Filesystem has less disk space than required."
            exit 126
        fi
        echo "Extracting images..."
        sudo tar -xvf $tarName
        exitCode=$?
        if [ $exitCode -ne 0 ]; then
            echo "Error during decompressing tar."
        fi

        spaceleft=$(sudo df -h $(pwd) | tail -n -1  | awk '{print $4}'| tr -d Gi)
        if [[ $spaceleft -lt $requiredTarSpace ]]; then
            echo "You do not have enough space in Docker ($dockerpath) to docker save all of Sosivio's images."
            exit 126
        fi

        if [ -d $(pwd)/$directoryName ]; then
            echo "Found \"$directoryName\" in current directory."
        else
            echo "Did not find \"$directoryName\" in current directory."
            exit 1
        fi

        for i in $(ls $directoryName );
        do
            sudo docker load -q -i $(pwd)/$directoryName/$i
        done
        exitCode=$?
        if [ $exitCode -ne 0 ]; then
            echo "Something went wrong with \"sudo docker load\" command."
            exit $exitCode
        fi

        echo -e "\nTagging and Pushing Images\...n"
        for i in "${microServices[@]}";
        do
            echo "Tagging image $i"
            sudo docker tag $ourDockerRepo/$i:$version $clientRegistry/$clientRegistryPath/$i:$version
            echo "Pushing image $i"
            sudo docker push $clientRegistry/$clientRegistryPath/$i:$version
        done
    else
        echo "The values for flags are not correct"
        exit 1
    fi
fi
