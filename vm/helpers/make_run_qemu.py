#!/usr/bin/python3
import json
import os
import subprocess
import sys

# To be executed in qemu container, as we need ports and volumes User could attach
       
default_run_str = '''#!/bin/sh 
accel="-M microvm,x-option-roms=off,isa-serial=off -machine acpi=off"
if [ -e /dev/kvm ]; then
    echo "Using hardware accelerartion!"
    accel="-M microvm,x-option-roms=off,isa-serial=off,rtc=off -machine acpi=off -enable-kvm -cpu host"
fi

qemu-system-x86_64 $accel -nodefaults -no-user-config \
    -nographic -no-reboot -device virtio-serial-device \
    -chardev stdio,id=virtiocon0 \
    -device virtconsole,chardev=virtiocon0 \
    -drive id=root,file=/rootfs-diff.qcow2,format=qcow2,if=none -device virtio-blk-device,drive=root \
    -kernel /kernel \
    -append "console=hvc0 root=/dev/vda rw acpi=off reboot=t panic=-1" \
    -device virtio-rng-device \
    -netdev user,id=mynet0,net=10.0.2.0/24,dhcpstart=10.0.2.15,$$PORT_MAPPING$$ -device virtio-net-device,netdev=mynet0'''


_port_bindings = [ "hostfwd=tcp::8666-:8666" ]# ThorFI Server port by default
_ext_volume_bindings = [] # Volume bindigns to add to qemu run command
# TODO: Entrypoint must be handled before running target app

    
# Legge l'argomento dalla shell
if len(sys.argv) < 2:
    print("Please specify container name")
    sys.exit()
_container_name = sys.argv[1]

_output_file = "run.sh"

if len(sys.argv) == 3:
    _output_file = sys.argv[2]
    

try:
    ## Docker Image bindings
    # # Eseguire il comando shell e acquisire l'output come stringa
    # output = subprocess.check_output(["docker", "inspect", _image_name])
    # # Decodificare l'output JSON in un dizionario Python
    # json_object = json.loads(output)

    # data = json.loads(output.decode('utf-8'))
    
    # _config_node = data[0]["ContainerConfig"]
    
    # for i, elem in enumerate(_config_node["ExposedPorts"]):
    #     bind = elem.split("/")
    #     _port_bindings.append("hostfwd="+bind[1]+"::"+bind[0]+"-:"+bind[0])
    # _port_bindings_str = ",".join(_port_bindings)
    
    # print(_port_bindings_str)
    
    # Docker container bindings
    
    output = subprocess.check_output(["docker", "inspect", _container_name])
    json_object = json.loads(output)
    data = json.loads(output.decode('utf-8'))
    _config_node = data[0]["HostConfig"] 
    
    # Ports
    if _config_node["PortBindings"] is not None:
        for i, elem in enumerate(_config_node["PortBindings"]):
            bind = elem.split("/")
            _port_bindings.append("hostfwd="+bind[1]+"::"+bind[0]+"-:"+bind[0])
    _port_bindings_str = ",".join(_port_bindings)
    default_run_str = default_run_str.replace("$$PORT_MAPPING$$", _port_bindings_str )
    
    # Volumes
    if _config_node["Binds"] is not None:
        for i, elem in enumerate(_config_node["Binds"]):
            vbind = elem.split(":")
            _ext_volume_bindings.append(" -fsdev local,id=bind"+str(i)+",path="+vbind[1]+",security_model=none,multidevs=remap -device virtio-9p-device,fsdev=bind"+str(i)+",mount_tag=mount_bind"+str(i))
    _ext_volume_bindings_str = " ".join(_ext_volume_bindings)
    if len(_ext_volume_bindings) > 0:
        default_run_str = default_run_str + _ext_volume_bindings_str

    
    with open(_output_file, "w") as f:
        # Scrivi le variabili nel file, una per riga
        f.write(default_run_str)
    
    
except subprocess.CalledProcessError as e:
    # L'output non è un JSON valido
    print("Error: wrong container name or...")