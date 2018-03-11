#!/bin/bash
mkdir -p /opt/bin
sudo curl -L https://github.com/docker/compose/releases/download/1.19.0/docker-compose-`uname -s`-`uname -m` -o /opt/bin/docker-compose
chown -R core:core /opt
chmod +x /opt/bin/docker-compose
