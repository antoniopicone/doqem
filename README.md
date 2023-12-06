# Doqem

A framework to convert a Docker image in a lightweight QEMU virtual machine running in a Docker container!

![](https://github.com/antoniopicone/doqem/doqem.gif)

## Create (or pull) Doqem image
Doqem is the tool to enclose your target image in an isolated environment.

You just need to build the tool once ;) 

```bash
docker build . -t doqem
```
For convenience, you can now create an alias for Doqem:
```bash
alias doqem="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock doqem"
```

## Doqem-ify a Docker image and push it to the local registry
To create a Doqem Docker image, just run `doqem <docker_image>`.
You can add port and/or volume bindings: let's say, for example, you want to test **nginx** docker image and expose 80 port of nginx to 8080 of docker context: to do that, just build a *Doqem* nginx image adding the port binding to the build command:

```bash
doqem build -p 8080:80 nginx
```

This will generate a new Docker image named `doqem_<docker_image>` with exposed port 80 of the (VM running in a) container on the 8080 port of your Docker context.

**Important**: don't forget to build your Doqem image with port(s) and/or volume(s) you want later as Doqem needs to be aware of those.

## Run 
Now it's all set and you can run nginx in an isolated virtual machine inside a Docker container:
```bash
docker run \
    -it --name my_doqem_app --rm \
    -p 8080:80 \
    doqem_nginx 
```

**Hardware Acceleration is supported**, so, if you have KVM enabled, add `--device /dev/kvm:/dev/kvm` to your docker run command!
