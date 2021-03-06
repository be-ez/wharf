#!/bin/bash

set -eux -o pipefail

REDIS_URL=dummy python3 manage.py test
wget -nv -O - https://packagecloud.io/dokku/dokku/gpgkey | sudo apt-key add -
echo "deb https://packagecloud.io/dokku/dokku/ubuntu/ xenial main" | sudo tee /etc/apt/sources.list.d/dokku.list
sudo apt-get update
sudo apt-get install -y dokku
sudo dokku plugin:install-dependencies --core
(dokku plugin:list | grep redis) || sudo dokku plugin:install https://github.com/dokku/dokku-redis.git redis
(dokku plugin:list | grep postgres) || sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
(dokku plugin:list | grep letsencrypt) || sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
dokku letsencrypt:cron-job --add
(dokku apps:list | grep wharf) || dokku apps:create wharf
(dokku redis:list | grep wharf) || (dokku redis:create wharf && dokku redis:link wharf wharf)
(dokku postgres:list | grep wharf) || (dokku postgres:create wharf && dokku postgres:link wharf wharf)
(git remote | grep dokku) || git remote add dokku ssh://dokku@localhost/wharf
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    yes y | ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
fi
(dokku ssh-keys:list | grep travis) || sudo dokku ssh-keys:add travis ~/.ssh/id_rsa.pub
GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git push dokku HEAD:refs/heads/master
python3 check_boot.py $(dokku url wharf)