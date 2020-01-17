# Jenkins LTS - Nginx - Docker

**What is Jenkins?**

- Jenkins offers a simple way to set up a continuous integration or continuous delivery environment for almost any combination of languages and source code repositories using pipelines, as well as automating other routine development tasks. While Jenkins doesn’t eliminate the need to create scripts for individual steps, it does give you a faster and more robust way to integrate your entire chain of build, test, and deployment tools than you can easily build yourself.


This work is based on the Official Jenkins Docker Image [[1](https://github.com/jenkinsci/docker)].

Docker doesn't recommend running the Docker daemon inside a container (except for very few use cases like developing Docker itself), and the solutions to make this happen are generally hacky and/or unreliable.

Fear not though, there is an easy workaround: mount the host machine's Docker socket in the container. This will allow your container to use the host machine's Docker daemon to run containers and build images.

Your container still needs compatible Docker client binaries in it, but I have found this to be acceptable for all my use cases. [[2](https://getintodevops.com/blog/the-simple-way-to-run-docker-in-docker-for-ci)]

## Table of Contents

- [Setup and configuration](#setup) - customize for version of Docker being run
- [HTTP or HTTPS?](#http-or-https) - which protocol to use for your instance
- [SSL Certificates](#ssl-certs) - configure for using SSL certificates
- [.env](#dot-env) - variable declaration for docker-compose to use
- [Deploy](#deploy) - deploying your Jenkins site
- [Running site](#site) - what to expect after you deploy
- [Trouble Shooting](#debugging) - debugging common issues

## <a name="setup"></a>Configuration

### Create directories on host

Directories are created on the host and volume mounted to the docker containers. This allows the user to persist data beyond the scope of the container itself. If volumes are not persisted to the host the user runs the risk of losing their data when the container is updated or removed.

- **jenkins_home**: The Jenkins application and job files
- **logs/nginx**: The Nginx log files (error.log, access.log)
- **certs**: SSL certificate files

From the top level of the cloned repository, create the directories that will be used for managing the data on the host.

```
mkdir -p jenkins_home/ logs/nginx/ certs/
```

**NOTE**: for permissions reasons it is important for the user to create these directories prior to issuing the docker-compose command. If the directories do not already exist when the containers are started, the directories will be created at start time and will be owned by the root user of the container process. This can lead to access denied permission issues.

### Docker version

The version of Docker being run inside the container should be the same as the host it is being deployed as to mitigate against unforseen issues.

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

- Debian based versions of `docker-ce` available as of 2020-01-17:

  ```console
  # apt-cache madison docker-ce | tr -s ' ' | cut -d '|' -f 2
   5:19.03.5~3-0~debian-stretch
   5:19.03.4~3-0~debian-stretch
   5:19.03.3~3-0~debian-stretch
   5:19.03.2~3-0~debian-stretch
   5:19.03.1~3-0~debian-stretch
   5:19.03.0~3-0~debian-stretch
   5:18.09.9~3-0~debian-stretch
   5:18.09.8~3-0~debian-stretch
   5:18.09.7~3-0~debian-stretch
   5:18.09.6~3-0~debian-stretch
   5:18.09.5~3-0~debian-stretch
   5:18.09.4~3-0~debian-stretch
   5:18.09.3~3-0~debian-stretch
   5:18.09.2~3-0~debian-stretch
   5:18.09.1~3-0~debian-stretch
   5:18.09.0~3-0~debian-stretch
   18.06.3~ce~3-0~debian
   18.06.2~ce~3-0~debian
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

### UID/GID

The UID and GID of the `jenkins` user that runs within the container are modifiable to allow the mounting of host volumes to the container to match that of a user on the host.

From `.env`

```env
# jenkins - jenkins.nginx.docker:lts
UID_JENKINS=1000
GID_JENKINS=1000
...
```

The Jenkins Docker image creates a user named `jenkins` with `UID/GID` = `1000/1000`. This is not always an ideal UID/GID pairing when wanting to use mounted volumes, so the notion of changing the UID/GID of the jenkins user exists.

In order to facilitate this the `root` user must issue some commands at start up, and thus a new `docker-entrypoint.sh` script has been introduced. This new script then calls the original `jenkins.sh` script as the `jenkins` user on it's way out.

The new `docker-entrypoint.sh` script is prefixed to use Tini [[4](https://github.com/krallin/tini/issues/8)] as was the case for the `jenkins.sh` script from the original image.

## <a name="http-or-https"></a>HTTP or HTTPS?

There are three files in the `nginx` directory, and which one you use depends on whether you want to serve your site using HTTP or HTTPS.

Files in the `nginx` directory:

- `default.conf` - Example configuration for running locally on port 80 using http.
- `default_http.conf.template` - Example configuration for running at a user defined `FQDN_OR_IP` on port 80 using http.
- `default_https.conf.template` - Example configuration for running at a user defined `FQDN_OR_IP` on port 443 using https.

**NOTE**: `FQDN_OR_IP` is short for Fully Qualified Domain Name or IP Address, and should be DNS resolvable if using a hostname.

Both of these are protocols for transferring the information of a particular website between the Web Server and Web Browser. But what’s difference between these two? Well, extra "s" is present in https and that makes it secure! 

A very short and concise difference between http and https is that https is much more secure compared to http. https = http + cryptographic protocols.

Main differences between HTTP and HTTPS

- In HTTP, URL begins with [http://]() whereas an HTTPS URL starts with [https://]()
- HTTP uses port number `80` for communication and HTTPS uses `443`
- HTTP is considered to be unsecured and HTTPS is secure
- HTTP Works at Application Layer and HTTPS works at Transport Layer
- In HTTP, Encryption is absent whereas Encryption is present in HTTPS
- HTTP does not require any certificates and HTTPS needs SSL Certificates (signed, unsigned or self generated)

### HTTP

If you plan to run your Jenkins site over http on port 80, then do the following.

1. Replace the contents of `nginx/default.conf` with the `nginx/default_http.conf.template` file 
2. Update the `FQDN_OR_IP` in `nginx/default.conf` to be that of your domain

### HTTPS

If you plan to run your WordPress site over https on port 443, then do the following.

1. Replace the contents of `nginx/default.conf` with the `nginx/default_https.conf.template` file. 
2. Update the `FQDN_OR_IP` in `nginx/default.conf` to be that of your domain (occurs in many places)
3. Review the options for SSL certificates below to complete your configuration

## <a name="ssl-certs"></a>SSL Certificates

**What are SSL Certificates?**

SSL Certificates are small data files that digitally bind a cryptographic key to an organization’s details. When installed on a web server, it activates the padlock and the https protocol and allows secure connections from a web server to a browser. Typically, SSL is used to secure credit card transactions, data transfer and logins, and more recently is becoming the norm when securing browsing of social media sites.

SSL Certificates bind together:

- A domain name, server name or hostname.
- An organizational identity (i.e. company name) and location.

### Example using self signed certificates 

Generate your certificates (example using `.pem` format)

```
cd certs
openssl req -x509 \
  -newkey rsa:4096 \
  -keyout self_signed_key.pem \
  -out self_signed_cert.pem \
  -days 365 \
  -nodes -subj '/CN='$(hostname)
```

Uncomment the `NGINX_SSL_CERT` and `NGINX_SSL_KEY ` lines in the `docker-compose.yml` file

```yaml
...
    volumes:
      - ${NGINX_DEFAULT_CONF:-./nginx/default.con}:/etc/nginx/conf.d/default.conf
      - ./logs/nginx:/var/log/nginx
      - ${NGINX_SSL_CERT:-./certs/self_signed_cert.pem}:/etc/nginx/ssl/server.crt
      - ${NGINX_SSL_KEY:-./certs/self_signed_key.pem}:/etc/nginx/ssl/server.key/
...
```

**NOTE**: the `NGINX_SSL_CERT ` and `NGINX_SSL_KEY ` values may need to be adjusted in the `.env` file to match your deployment

## <a name="dot-env"></a>.env

A `.env` file has been included to more easily set docker-compose variables without having to modify the `docker-compose.yml` file itself.

Default values have been provided as a means of getting up and running quickly for testing purposes. It is up to the user to modify these to best suit their deployment preferences.

Example .env file:

```
# jenkins - jenkins.nginx.docker:lts
UID_JENKINS=1000
GID_JENKINS=1000
JENKINS_OPTS="--prefix=/jenkins"

# nginx - nginx:latest
NGINX_DEFAULT_CONF=./nginx/default.conf
NGINX_SSL_CERT=./certs/self_signed_cert.pem
NGINX_SSL_KEY=./certs/self_signed_key.pem
```

## <a name="deploy"></a>Deploy

Use docker-compose from the top level of the repository to run the containers. Generally this is done using the `-d` flag to daemonize the processes.

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

It may take a few minutes for the Jenkins container to complete it's initial setup, but once completed you should find your running site at:

- HTTP: [http://FQDN\_OR\_IP/jenkins]()
- HTTPS: [https://FQDN\_OR\_IP/jenkins]()

## <a name="site"></a>Running site

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

Issue a docker command from the Jenkins container to the host. For example, running `docker ps` from inside of the Jenkins container should result in something like:

```console
$ docker exec -u jenkins jenkins sudo docker ps
CONTAINER ID        IMAGE                      COMMAND                  CREATED             STATUS              PORTS                                                                                NAMES
771a9c9fde17        jenkins.nginx.docker:lts   "/sbin/tini -- /dock…"   11 minutes ago      Up 11 minutes       0.0.0.0:50000->50000/tcp, 8080/tcp, 0.0.0.0:50022->50022/tcp, 0.0.0.0:2022->22/tcp   jenkins
d68e3b96071e        nginx:latest               "nginx -g 'daemon of…"   11 minutes ago      Up 11 minutes       0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp                                             nginx
```

## <a name="debugging"></a>Trouble Shooting

### Nginx configuration

Since the `default.conf` file is mounted from the host it can be updated in real-time. Once changes have been made, the user should validate and reload the configuration.

- Example validation:

  ```console
  $ docker exec nginx /usr/sbin/nginx -t
  nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
  nginx: configuration file /etc/nginx/nginx.conf test is successful
  ```

- Example reload:

  ```console
  $ docker exec nginx /usr/sbin/nginx -s reload
  Reloading nginx: nginx.
  ```


## References

[1] Official Jenkins Docker Image: [https://github.com/jenkinsci/docker](https://github.com/jenkinsci/docker)

[2] Get into DevOps (blog): [https://getintodevops.com/blog/the-simple-way-to-run-docker-in-docker-for-ci](https://getintodevops.com/blog/the-simple-way-to-run-docker-in-docker-for-ci)

[3] Docker Compose Github Releases: [https://github.com/docker/compose/releases](https://github.com/docker/compose/releases)

[4] Advantage of Tini: [https://github.com/krallin/tini/issues/8](https://github.com/krallin/tini/issues/8)

[5] Jenkins behind an NGinX reverse proxy: [https://wiki.jenkins.io/display/JENKINS/Jenkins+behind+an+NGinX+reverse+proxy](https://wiki.jenkins.io/display/JENKINS/Jenkins+behind+an+NGinX+reverse+proxy)
