# Jenkins LTS - Nginx - Docker

This work is based on the Official Jenkins Docker Image [[1](https://github.com/jenkinsci/docker)].

Docker doesn't recommend running the Docker daemon inside a container (except for very few use cases like developing Docker itself), and the solutions to make this happen are generally hacky and/or unreliable.

Fear not though, there is an easy workaround: mount the host machine's Docker socket in the container. This will allow your container to use the host machine's Docker daemon to run containers and build images.

Your container still needs compatible Docker client binaries in it, but I have found this to be acceptable for all my use cases. [[2](https://getintodevops.com/blog/the-simple-way-to-run-docker-in-docker-for-ci)]

## Build

In the [Dockerfile](Dockerfile), set the value of `ARG docker_version=` to correspond to the same version of `docker-ce` that is running on the host. The default value is `17.12.0~ce-0~debian`.

The version of `docker-ce` on the host can be found by issuing a `docker version` call.

- Example:

    ```console
    $ docker version
    Client:
     Version:	17.12.0-ce
     API version:	1.35
     Go version:	go1.9.2
     Git commit:	c97c6d6
     Built:	Wed Dec 27 20:03:51 2017
     OS/Arch:	darwin/amd64
    
    Server:
     Engine:
      Version:	17.12.0-ce
      API version:	1.35 (minimum version 1.12)
      Go version:	go1.9.2
      Git commit:	c97c6d6
      Built:	Wed Dec 27 20:12:29 2017
      OS/Arch:	linux/amd64
      Experimental:	true
    ```
	In this example the version was found to be `17.12.0-ce`, so the value of `docker_version` in the [Dockerfile](Dockerfile) should be set to `17.12.0~ce-0~debian` prior to building the image.

- Debian based versions of `docker-ce` available as of 2018-09-21:

	```console
	# apt-cache madison docker-ce | tr -s ' ' | cut -d '|' -f 2
	 18.06.1~ce~3-0~debian
	 18.06.0~ce~3-0~debian
	 18.03.1~ce-0~debian
	 18.03.0~ce-0~debian
	 17.12.1~ce-0~debian
	 17.12.0~ce-0~debian
	 17.09.1~ce-0~debian
	 17.09.0~ce-0~debian
	 17.06.2~ce-0~debian
	 17.06.1~ce-0~debian
	 17.06.0~ce-0~debian
	 17.03.3~ce-0~debian-stretch
	 17.03.2~ce-0~debian-stretch
	 17.03.1~ce-0~debian-stretch
	 17.03.0~ce-0~debian-stretch
	 ```
 
	Versions are subject to change as time goes on and keeping this reference up to date is outside of the scope of this document.

Once the value of `ARG docker_version=` has been set, the jenkins container can be built using `docker-compose` [[3](https://github.com/docker/compose/releases)].

```
docker-compose build
```

The resulting image should look something like:

```console
$ docker images
REPOSITORY                   TAG                 IMAGE ID            CREATED             SIZE
jenkins.nginx.docker         lts                 3b61f3afc888        2 minutes ago       1.26GB
```

## Configure

This build makes use of docker-compse which is released as a separate distribution from Docker.

### UID/GID

An option has been added to allow the user to modify the UID and GID of the `jenkins` user that runs within the container. This can be useful to allow the mounting of volumes to the container and maintain UID/GID combinations that are native to the host.

- Example from `docker-compose.yml`:

	```yaml
	environment:
	  - UID_JENKINS=1000
	  - GID_JENKINS=1000
	```

The official Jenkins Docker image creates a user named `jenkins` with `UID/GID` = `1000/1000`. This is not always an ideal UID/GID pairing when wanting to use mounted volumes, so the notion of changing the UID/GID of the jenkins user has been introduced.

In order to facilitate this the `root` user must issue some commands at start up, and thus a new `docker-entrypoint.sh` script has been introduced. This new script then calls the original `jenkins.sh` script as the `jenkins` user on it's way out.

The new `docker-entrypoint.sh` script is prefixed to use Tini [[4](https://github.com/krallin/tini/issues/8)] as was the case for the `jenkins.sh` script from the original image.

### Mounted Volumes

The user may also define mount volumes for both the Nginx and Jenkins containers.

Default settings for `nginx`:

```yaml
volumes:
  - ./nginx:/etc/nginx/conf.d
  - ./logs/nginx:/var/log/nginx
```

Default settings for `jenkins`:

```yaml
volumes:
  - ./jenkins_home:/var/jenkins_home
  - /var/run/docker.sock:/var/run/docker.sock
```

### Nginx

The `nginx/default.conf` file is used to determine the behavior of the Nginx reverse proxy web server [[5](https://wiki.jenkins.io/display/JENKINS/Jenkins+behind+an+NGinX+reverse+proxy)], and should be modified to fit the use case. Template files for both http and https have been included as examples.

Update `FQDN_OR_IP` to be the fully qualified domain name or IP address of the host.

## Run

Use docker-compose to run the containers. Generally this is done using the `-d` flag to daemonize the processes.

```
docker-compose up -d
```

A successful run will yield two new containers, `nginx` and `jenkins`.

```console
$ docker ps
CONTAINER ID        IMAGE                      COMMAND                  CREATED             STATUS              PORTS                                                                                NAMES
3266e71ecb05        nginx:latest               "nginx -g 'daemon of…"   About an hour ago   Up About an hour    0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp                                             nginx
0970db06246b        jenkins.nginx.docker:lts   "/sbin/tini -- /dock…"   About an hour ago   Up About an hour    0.0.0.0:50000->50000/tcp, 8080/tcp, 0.0.0.0:50022->50022/tcp, 0.0.0.0:2022->22/tcp   jenkins
```

Using the configuration provided in the repository you should now have a running instance of Jenkins at [http://localhost/jenkins](http://localhost/jenkins)

First run:

<img width="80%" alt="Jenkins Start Screen" src="https://user-images.githubusercontent.com/5332509/35367465-5ecd455c-014c-11e8-92b4-97bcdae36cf8.png">

To retrieve the `initialAdminPassword`:

```console
$ docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
455341501512421c82f46f7d7bed27d0
```

And paste the result into the **Administrator password** box.
From here continue to customize Jenkins to your particular requirements.

<img width="80%" alt="Customize Jenkins" src="https://user-images.githubusercontent.com/5332509/35367475-73a7bffc-014c-11e8-9b2e-c1dad1f0a482.png">

### Validate Docker from Jenkins

```console
$ docker exec -u jenkins jenkins sudo docker ps
CONTAINER ID        IMAGE                      COMMAND                  CREATED             STATUS              PORTS                                                                                NAMES
3266e71ecb05        nginx:latest               "nginx -g 'daemon of…"   About an hour ago   Up About an hour    0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp                                             nginx
0970db06246b        jenkins.nginx.docker:lts   "/sbin/tini -- /dock…"   About an hour ago   Up About an hour    0.0.0.0:50000->50000/tcp, 8080/tcp, 0.0.0.0:50022->50022/tcp, 0.0.0.0:2022->22/tcp   jenkins
```

## Trouble Shooting

### Nginx configuration

Since the `default.conf` file is mounted from the host it can be updated in real-time. Once changes have been made, the user should validate and reload the configuration.

- Example validation:

    ```console
    $ docker exec nginx /etc/init.d/nginx configtest
    nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    nginx: configuration file /etc/nginx/nginx.conf test is successful
    ```

- Example reload:

    ```console
    $ docker exec nginx /etc/init.d/nginx reload
    Reloading nginx: nginx.
    ```


## References

[1] Official Jenkins Docker Image: [https://github.com/jenkinsci/docker](https://github.com/jenkinsci/docker)

[2] Get into DevOps (blog): [https://getintodevops.com/blog/the-simple-way-to-run-docker-in-docker-for-ci](https://getintodevops.com/blog/the-simple-way-to-run-docker-in-docker-for-ci)

[3] Docker Compose Github Releases: [https://github.com/docker/compose/releases](https://github.com/docker/compose/releases)

[4] Advantage of Tini: [https://github.com/krallin/tini/issues/8](https://github.com/krallin/tini/issues/8)

[5] Jenkins behind an NGinX reverse proxy: [https://wiki.jenkins.io/display/JENKINS/Jenkins+behind+an+NGinX+reverse+proxy](https://wiki.jenkins.io/display/JENKINS/Jenkins+behind+an+NGinX+reverse+proxy)
