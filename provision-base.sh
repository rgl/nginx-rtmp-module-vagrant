#!/bin/bash
# abort this script on errors.
set -eux

# prevent apt-get et al from opening stdin.
# NB even with this, you'll still get some warnings that you can ignore:
#     dpkg-preconfigure: unable to re-open stdin: No such file or directory
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git-core
apt-get install -y unzip xz-utils
apt-get install -y --no-install-recommends httpie
apt-get install -y --no-install-recommends vim
apt-get install -y --no-install-recommends jq

# set system configuration.
rm -f /{root,home/*}/.{profile,bashrc}
cp -v -r /vagrant/config/etc/* /etc

su vagrant -c bash <<'VAGRANT_EOF'
#!/bin/bash
# abort this script on errors.
set -eux

# configure git.
# see http://stackoverflow.com/a/12492094/477532
git config --global user.name 'Rui Lopes'
git config --global user.email 'rgl@ruilopes.com'
git config --global push.default simple
#git config --list --show-origin
VAGRANT_EOF

apt-get autoremove -y --purge
