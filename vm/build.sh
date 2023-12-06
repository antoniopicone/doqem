#!/bin/bash

## Usage decalration

if [ $# -lt 1 ]; then
    echo ""
    echo "Usage:"
    echo "  build [OPTIONS] IMAGE"
    # echo "  $0 -f <path_to_dockerfile>"
    echo ""
    echo "Where options allowed are -p and -v to specify port and volume bindings"
    echo "For example: "
    echo "   build -p 8000:80 nginx"
    echo "   build -v ./app:/app python:3.19.6"
    echo "   build -p 8000:80 -v /tmp:/var/www nginx"
    echo ""    
    exit 1
fi

## Strip port(s) and/or volume(s) bindings from image name

ports=()
volumes=()
envs=()

while getopts ":p:v:e:" opt; do
  case ${opt} in
    p ) 
      ports+=("$OPTARG")
      ;;
    v )
      volumes+=("$OPTARG")
      ;;
    e )
      envs+=("$OPTARG")
      ;;
    \? )
      echo "Invalid option: -$OPTARG" 1>&2
      ;;
    : )
      echo "Option -$OPTARG requires an argument." 1>&2
      ;;
  esac
done

shift $((OPTIND -1))

if [ $# -ne 1 ]; then
  echo "Error: exactly one image name is required"
  exit 1
fi

## Define image and container name for target
image_name=$@
cnt_name="doqem_target_image"

port_bindings=""
volume_bindings=""
env_variables=""

for port in "${ports[@]}"; do
  port_bindings+=" -p $port"
done

for volume in "${volumes[@]}"; do
  volume_bindings+=" -v $volume"
done

for env_var in "${envs[@]}"; do
    export $env_var
done


# Check if image name contains a tag/version, otherwise add "latest"
if [[ "$image_name" != *":"* ]]; then
    image_name="$image_name:latest"
fi

## Here we go!
echo ""
echo "Building a doqem image for $image_name"
if [ ${#ports[@]} -gt 0 ] || [ ${#volumes[@]} -gt 0 ]; then
    echo "with following binding(s):"   
fi
if [ ${#ports[@]} -gt 0 ]; then
  echo "Ports: ${ports[@]}"
fi
if [ ${#volumes[@]} -gt 0 ]; then
  echo "Volumes: ${volumes[@]}"
fi
echo ""

if [ ! -f /kernel/kernel512b ]; then
    echo "- Building kernel from scratch with minimal config for microVM"
    cd kernel
    ./build_kernel.sh 2>&1 1>/dev/null
    cd ..
fi

echo "- Pulling image $image_name from registry"
pull_command=$(docker pull $image_name 2>&1 1>/dev/null)
if echo "$pull_command" | grep -iq "Error"; then
    echo ""
    echo "Image $image_name not found, exiting. :("
    echo ""
    exit 1
fi

echo "- Checking Linux ditribution and installing base networking tools..."
apk_command=$(docker run --rm $image_name sh -c "apk" 2>/dev/null)
apt_command=$(docker run --rm $image_name sh -c "apt" 2>/dev/null)
dnf_command=$(docker run --rm $image_name sh -c "dnf" 2>/dev/null)


if echo "$apk_command" | grep -iq "usage"; then
    #echo "Alpine"
    docker run $port_bindings $volume_bindings --quiet --name $cnt_name $image_name /bin/sh -c "apk update && apk add iputils net-tools iproute2 python3 execline bash" 2>&1 1>/dev/null
elif echo "$apt_command" | grep -iq "usage"; then
    #echo "Debian/Ubuntu"
    docker run $port_bindings $volume_bindings --quiet --name $cnt_name $image_name /bin/sh -c "export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get install -qy net-tools iproute2 iputils-ping python3 execline bash 2>&1 1>/dev/null" 2>&1 1>/dev/null

elif echo "$dnf_command" | grep -iq "usage"; then
    #echo "Fedora/Centos"
    docker run $port_bindings $volume_bindings --quiet --name $cnt_name $image_name /bin/sh -c "dnf install net-tools iproute iputils python3 execline bash -y" 2>&1 1>/dev/null
else
    echo "Unrecognized package manager, exiting. :("
    exit 1
fi

mkdir -p build

echo "- Creating init and adding target app entrypoint"
python3 make_init.py $cnt_name build/init 
chmod +x build/init

echo "- Creating run Qemu command for $image_name"
python3 make_run_qemu.py $cnt_name build/run.sh 
chmod +x build/run.sh


echo "- Copying init in target container"
docker cp build/init $cnt_name:/sbin/init >/dev/null
# docker cp thorfi/thorfi_server.py $cnt_name:/thorfi_server.py >/dev/null
rm -f build/init

echo "- Exporting rootfs from target container"
docker export --output="build/rootfs.tar" $cnt_name 2>&1 1>/dev/null

echo "- Removing temporary target container"
docker stop $cnt_name 2>&1 1>/dev/null
docker rm $cnt_name 2>&1 1>/dev/null

echo "- Shrinking and converting rootfs to qcow2"
cd build
sudo virt-make-fs --format=qcow2 --size=+300M rootfs.tar rootfs-large.qcow2
rm -f rootfs.tar
qemu-img convert rootfs-large.qcow2 -O qcow2 rootfs.qcow2
rm -f rootfs-large.qcow2
qemu-img create -f qcow2 -b rootfs.qcow2 -F qcow2 rootfs-diff.qcow2 2>&1 1>/dev/null
cd ..

echo "- Creating doqem image"
docker build --quiet --no-cache -t doqem_$1 . -f doqem_container.Dockerfile 2>&1 1>/dev/null
echo ""
echo "All Done!"
echo ""
echo "Your doqem image is available as doqem_$1, you can run it with:"
echo ""
echo "      docker run $port_bindings $volume_bindings doqem_$1"
echo ""
echo ""