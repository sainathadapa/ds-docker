#!/bin/bash
add-apt-repository -y ppa:fish-shell/release-2
apt-get update
apt-get install -y fish
curl -fsSL https://download.docker.com/linux/ubuntu/gpg > tmpkey
apt-key add tmpkey
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable edge"
apt-get install -y docker-ce
