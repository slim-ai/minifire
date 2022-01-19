#!/bin/bash

export PATH=$PATH:~/repos/cli-aws

set -xeou pipefail

name=minifire

aws-vpc-ensure adhoc-vpc

aws-ec2-ensure-sg adhoc-vpc adhoc-vpc tcp:22:0.0.0.0/0 tcp:443:0.0.0.0/0

cli-aws ec2-ensure-keypair p52 ~/.ssh/id_ed25519.pub

if ! id=$(cli-aws ec2-id $name); then
    id=$(cli-aws ec2-new \
                 -k p52 \
                 --sg adhoc-vpc \
                 --vpc adhoc-vpc \
                 --spot lowestPrice \
                 -t z1d.2xlarge \
                 -a arch \
                 --gigs 8 \
                 --seconds-timeout $((60*60*5)) \
                 $name)
fi

cli-aws ec2-wait-ssh $id -y

cli-aws ec2-ssh -y $id -c '
    set -xeou pipefail
    while true; do
        df /mnt && break
        echo waiting for /mnt
        sleep 1
    done
    echo "Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch" | sudo tee /etc/pacman.d/mirrorlist
    echo "Server = https://mirrors.xtom.com/archlinux/\$repo/os/\$arch"   | sudo tee -a /etc/pacman.d/mirrorlist
    echo "Server = https://mirror.lty.me/archlinux/\$repo/os/\$arch"      | sudo tee -a /etc/pacman.d/mirrorlist
    sudo pacman -Sy --noconfirm archlinux-keyring
    sudo pacman -Syyu --noconfirm
    sudo pacman -Sy --noconfirm --needed nss rsync docker docker-compose readline go entr jq caddy lego python
    sudo usermod -a -G docker $USER
    ##
    sudo python -m ensurepip
    sudo python -m pip install glances[docker]
    ##
    go install github.com/nathants/docker-trace@latest
    echo "export PATH=\$PATH:~/go/bin" >> ~/.bashrc
    ##
    # install set-opt and bump limits
    curl -s https://raw.githubusercontent.com/nathants/bootstraps/0171d256009d133f3d923d324901dcc1bb4f8ea2/scripts/limits.sh | bash
    ##
    sudo systemctl stop containerd.service
    sudo systemctl stop docker.service
    set-opt /lib/systemd/system/docker.service ExecStart= "/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --data-root /mnt/docker-data --exec-root /mnt/docker-exec"
    set-opt /lib/systemd/system/containerd.service ExecStart= "/usr/bin/containerd --root /mnt/containerd-root --state /mnt/containerd-state"
    sudo systemctl daemon-reload
    sudo systemctl start containerd.service
    sudo systemctl start docker.service
    sudo systemctl enable containerd.service
    sudo systemctl enable docker.service
    ##
    set-opt /etc/default/grub "GRUB_CMDLINE_LINUX=" '"systemd.unified_cgroup_hierarchy=1"'
    sudo grub-mkconfig | sudo tee /boot/grub/grub.cfg
    ##
    echo "export PATH=\$PATH:~/go/bin" >> ~/.bashrc
'

cli-aws ec2-reboot $id -y

sleep 5

cli-aws ec2-wait-ssh $id -y

cli-aws ec2-ssh -y $id -c '
    timeout -s INT 30 ~/go/bin/docker-trace files || true
'
