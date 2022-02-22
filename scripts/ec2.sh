#!/bin/bash

set -xeou pipefail

if !which cli-aws &>/dev/null; then
    echo fatal, need to: go get github.com/nathants/cli-aws
fi

name=minifire
keypair=${KEYPAIR_NAME:-minifire}
keyfile=${KEYPAIR_PUBFILE:-~/.ssh/id_ed25519.pub}

args="
    --key $keypair
    --sg adhoc-vpc
    --vpc adhoc-vpc
    --gigs 8
    --seconds-timeout $((60*60*5))
    $name
"

if id=$(cli-aws ec2-id $name); then
    echo $id
    exit 0
fi

if ami=$(cli-aws ec2-latest-ami $name) && [ -z "${REBUILD:-}" ]; then
    cli-aws vpc-ensure adhoc-vpc
    cli-aws ec2-ensure-sg adhoc-vpc adhoc-vpc tcp:22:0.0.0.0/0 tcp:443:0.0.0.0/0
    cli-aws ec2-ensure-keypair $keypair $keyfile
    id=$(cli-aws ec2-new --type z1d.xlarge --ami $ami --spot lowestPrice $args)
    cli-aws ec2-wait-ssh $id
    cli-aws ec2-ssh $id -c "
        sudo systemctl stop containerd.service
        sudo systemctl stop docker.service
        set-opt /lib/systemd/system/docker.service ExecStart= '/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --data-root /mnt/docker-data --exec-root /mnt/docker-exec'
        set-opt /lib/systemd/system/containerd.service ExecStart= '/usr/bin/containerd --root /mnt/containerd-root --state /mnt/containerd-state'
        sudo systemctl daemon-reload
        while true; do
            if df | grep /mnt; then
                break
            fi
            echo wait for /mnt
            sleep 1
        done
        sudo systemctl restart containerd.service
        sudo systemctl restart docker.service
    "
    cli-aws ec2-ssh $id
    echo $id
    exit 0
fi

id=$(cli-aws ec2-new --type c5.large --ami arch --seconds-timeout 0 $args)

cli-aws ec2-wait-ssh $id

cli-aws ec2-ssh $id -c '
    set -xeou pipefail
    echo "Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch" | sudo tee /etc/pacman.d/mirrorlist
    echo "Server = https://mirrors.xtom.com/archlinux/\$repo/os/\$arch"   | sudo tee -a /etc/pacman.d/mirrorlist
    echo "Server = https://mirror.lty.me/archlinux/\$repo/os/\$arch"      | sudo tee -a /etc/pacman.d/mirrorlist
    sudo pacman -Sy --noconfirm archlinux-keyring
    sudo pacman -Syyu --noconfirm
    sudo pacman -Sy --noconfirm --needed nss rsync docker docker-compose readline go entr jq caddy lego python
    sudo usermod -a -G docker $USER
    ##
    sudo python -m ensurepip
    sudo python -m pip install yq glances[docker]
    ##
    go install github.com/nathants/docker-trace@latest
    go install github.com/nathants/cli-aws@latest
    echo "export PATH=\$PATH:~/go/bin" >> ~/.bashrc
    ##
    sudo systemctl enable containerd.service
    sudo systemctl enable docker.service
    ## install set-opt and bump limits
    curl -s https://raw.githubusercontent.com/nathants/bootstraps/0171d256009d133f3d923d324901dcc1bb4f8ea2/scripts/limits.sh | bash
    ##
    set-opt /etc/default/grub "GRUB_CMDLINE_LINUX=" '"systemd.unified_cgroup_hierarchy=1"'
    sudo grub-mkconfig | sudo tee /boot/grub/grub.cfg
'

cli-aws ec2-reboot $id

cli-aws ec2-wait-ssh $id

cli-aws ec2-ssh $id -c '
    timeout -s INT 60 ~/go/bin/docker-trace files || true
'
cli-aws ec2-stop $id --wait

cli-aws ec2-new-ami $name --wait

set -x
id=$(cli-aws ec2-new --type z1d.xlarge --ami $ami --spot lowestPrice $args)
cli-aws ec2-wait-ssh $id
cli-aws ec2-ssh $id -c "
    sudo systemctl stop containerd.service
    sudo systemctl stop docker.service
    set-opt /lib/systemd/system/docker.service ExecStart= '/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --data-root /mnt/docker-data --exec-root /mnt/docker-exec'
    set-opt /lib/systemd/system/containerd.service ExecStart= '/usr/bin/containerd --root /mnt/containerd-root --state /mnt/containerd-state'
    sudo systemctl daemon-reload
        while true; do
            if df | grep /mnt; then
                break
            fi
            echo wait for /mnt
            sleep 1
        done
    sudo systemctl restart containerd.service
    sudo systemctl restart docker.service
"
cli-aws ec2-ssh $id
echo $id
