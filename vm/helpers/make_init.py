#!/usr/bin/python3
import json
import subprocess
import sys
import os

# Set environment variables
force_shell = os.getenv('FORCE_SHELL', False)

base_entrypoint='''#!/bin/sh
# Create and mount filesystems

mkdir -p -m 755 /proc
mkdir -p -m 755 /dev/pts
mkdir -p -m 755 /dev/mqueue
mkdir -p -m 755 /dev/shm
mkdir -p -m 755 /sys
mkdir -p -m 755 /sys/fs/cgroup
mount -t proc proc /proc
mount -t devpts devpts /dev/pts
mount -t mqueue mqueue /dev/mqueue
mount -t tmpfs tmpfs /dev/shm
mount -t sysfs sysfs /sys
mount -t cgroup cgroup /sys/fs/cgroup

# Env
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

'''

post_vars = '''
# Base network configuration
hostname doqem-microvm
ifconfig eth0 10.0.2.15 netmask 255.255.255.0 && route add default gw 10.0.2.2
echo "nameserver 8.8.8.8" > /etc/resolv.conf

## # Start ThorFI server
## python3 /thorfi_server.py & 

'''

def parseElement(elem, concatstring='\n'):
    if elem is None:
        return ''
    if isinstance(elem, list):
        for i, _arg in enumerate(elem):
            if " " in _arg:
                elem[i] = '\"' + _arg + '\"'       
        return concatstring.join(elem)
    return elem
    

_int_volume_bindings = [] # Volume mounting instructions to be added to entrypoint

    
# Legge l'argomento dalla shell
if len(sys.argv) < 2:
    print("Please specify container name")
    sys.exit()
    
_container_name = sys.argv[1]

_output_file = "init"

if len(sys.argv) == 3:
    _output_file = sys.argv[2]

_image_name = ""

try:
    
    # Docker container bindings
    
    output = subprocess.check_output(["docker", "inspect", _container_name])
    json_object = json.loads(output)
    data = json.loads(output.decode('utf-8'))
    _image_name = data[0]["Config"]["Image"]
    _config_node = data[0]["HostConfig"] 
    
    # Volumes
    if _config_node["Binds"] is not None:
        for i, elem in enumerate(_config_node["Binds"]):
            vbind = elem.split(":")
            _int_volume_bindings.append("mount -t 9p -o trans=virtio mount_bind"+str(i)+" "+vbind[1]+" -oversion=9p2000.L,posixacl,msize=104857600,cache=none ")
        
    
except subprocess.CalledProcessError as e:
    # L'output non è un JSON valido
    print("Error: wrong container name or...")
    


try:
    # Eseguire il comando shell e acquisire l'output come stringa
    output = subprocess.check_output(["docker", "inspect", _image_name])
    # Decodificare l'output JSON in un dizionario Python
    json_object = json.loads(output)

    data = json.loads(output.decode('utf-8'))

    _config_node = data[0]["Config"]
    for i, elem in enumerate(_config_node["Env"]):
        if elem.startswith("PATH"):
            _config_node["Env"][i] = elem + ':$PATH'
        # _config_node["Env"][i] = "export " + elem
        _config_node["Env"][i] = _config_node["Env"][i].replace('"', '')
    
    env = parseElement(_config_node["Env"])
    working_dir = parseElement(_config_node["WorkingDir"])
    entry = parseElement(_config_node["Entrypoint"])
    cmd = parseElement(_config_node["Cmd"],' ')
    
    #print("Generating entrypoint file...")
    # Apri il file in modalità scrittura
    with open(_output_file, "w") as f:
        # Scrivi le variabili nel file, una per riga
        f.write(base_entrypoint)
        if len(_int_volume_bindings) > 0:
            for mount_row in _int_volume_bindings:
                f.write(mount_row + "\n")
        f.write("\n# Docker entrypoint" + "\n")
        if len(env) > 0:
            f.write("\n## Environment" + "\n")
            f.write(env + "\n")
        if len(working_dir) > 0:
            f.write("\n## Working directory" + "\n")
            f.write("cd " + working_dir + "\n")
        
        f.write(post_vars)
        
        if force_shell:
            print("  with forced /bin/bash shell on boot")
            f.write("\n## Forced shell" + "\n")
            f.write("/bin/bash" + "\n")
        else:
            if len(entry) > 0:
                f.write("\n## Entrypoint" + "\n")
                f.write(entry + "\n")
            if len(cmd) > 0:
                f.write("\n## Command" + "\n")
                f.write(cmd + "\n")
        
        
    os.chmod(_output_file, 0o755)

    # print the file's contents
    # with open(_output_file, "r") as f:
    #     print(f.read())       
    #print("done")
    
except subprocess.CalledProcessError as e:
    # L'output non è un JSON valido
    print("Error: wrong container name or...")