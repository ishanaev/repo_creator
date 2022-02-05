#!/bin/bash

curr_key=$(gpg --list-keys | awk 'NR==5{print $5}')
pubkey_id=$(gpg --list-keys | awk 'NR==4{print $1}')
gen_key_script=gen-key-script
codename=focal
ubuntu_version=20.04

set -e

create_repo() {
rm -rfv ./*
echo "APT { Get { AllowUnauthenticated \"1\"; }; };" > /etc/apt/apt.conf.d/99mycnf
echo "deb [ trusted=yes ] http://ppa.launchpad.net/gluster/glusterfs-10/ubuntu focal main" >> /etc/apt/sources.list
echo "deb [ trusted=yes ] http://ppa.launchpad.net/linuxuprising/libpng12/ubuntu focal main" >> /etc/apt/sources.list
apt update
apt --print-uris install $(cat ../pkgs.txt | tr -s '\n' ' ') -y | grep http:// | awk '{print $1}' | sed "s/'//g" > ../list_pkgs.txt
apt install wget reprepro gpg rename -y
wget -i ../list_pkgs.txt
rename -n 's|\%3a|\:|' * > ../renamed_pkgs.log
rename 's|\%3a|\:|' *
}

init_repo() {
if [ -d db -a -d dists ]; then
rm -rf db dists
fi
cat > conf/distributions <<-EOT
Codename: $codename
Suite: stable
Version: $ubuntu_version
Origin: Ubuntu
Label: Ubuntu $ubuntu_version
Description: Custom Local Repository
Architectures: amd64 source
Components: main
DebIndices: Packages Release . .gz .bz2
DscIndices: Sources Release . .gz .bz2
Contents: . .gz .bz2
SignWith: default
EOT
reprepro export
reprepro createsymlinks
reprepro --ask-passphrase includedeb $codename ../pkgs/*.deb
}

gen_key() {
export curr_key=$(gpg --list-keys | awk 'NR==5{print $5}')
export pubkey_id=$(gpg --list-keys | awk 'NR==4{print $1}')
# Удаляем текущий ключ, если имеется
if [ "$curr_key" == "local-repo" ]; then
yes | gpg --delete-secret-key $curr_key
yes | gpg --delete-key $curr_key
fi
cat > $gen_key_script <<-EOT
Key-Type: 1
Key-Length: 2048
Subkey-Type: 1
Subkey-Length: 2048
Name-Real: local-repo
Name-Email: admin@mail.n.o
Expire-Date: 0
EOT
gpg --batch --gen-key $gen_key_script
gpg --list-keys
gpg --armor --export > local-repo.asc
}

add_key() {
set -x
 apt-key add ../../../keys/local-repo.asc
yes y | gpg --armor -o Release.gpg -sb Release
}

rm -rf repo pkgs keys
mkdir -p repo/conf pkgs keys

# Создаём пакетный репозиторий
pushd pkgs
create_repo
popd

# Генерим подпись репозитория
pushd keys
gen_key
popd

# Инициализируем пакетный репозиторий
pushd repo
init_repo
popd
# Подписываем репозиторий
pushd repo/dists/focal
add_key
popd


