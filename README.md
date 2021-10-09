# download-script

This Project is for the download-script for clients who work in disconnected environements

## How does the client will use that script ?

1. The client will run the script like that : `./download-script.sh --pull`  
The script pulls images for the required version from Sosivio docker registry and put them all in a single tar.  
2. The client will copy that tar file to his disconnected environment with the ./download-script.sh.  
3. The client will run again the script this time like this : `./download-script --push`  
The client will be asked to fill 2 parameters what is the registry name to push the images too, and to what path in their registry.  
[registry](pictures/Screenshot from 2021-06-22 10-44-19.png)  
[registryPath](pictures/Screenshot from 2021-06-22 10-46-12.png)  
4. There is a docker login that the client must do in order to continue (it is also done in our script so he just needs to fill the username and password.)  
It happens right after he fills the parameters of step 3.
5. After entering a correct credentials for the registry he mentioned in step 3 then the images will be uploaded to the path which the client also specified in step 3 in the client registry.


## Help guide:
```
Sosivio-download-script manual:

Usage: sosivio-download-script --pull|--push [OPTIONS] 

Options: 
    --registryPath=   Directory path in the client's registry where Sosivio images will be saved. (only used with '--push').
    -h ,--help        Show help menu.
    --pull            Pulling Sosivio images and tar them. (is required if '--push' is not used)
    --push            Pushing Sosivio images to registry. (is required if '--pull' is not used)
    --registry=       Client registry DNS. (only used with '--push').
    --tarName=        Name for tar file with all the images. (default is 'SosivioImages.tgz')

Requirements:
    For pulling images: - connection to the internet and at least 12 GB of free disk space.
    For pushing images: - 18 GB of free disk space on the computer from which this script is running
                        - 12 GB free space in the client's docker image registry.
                        
```