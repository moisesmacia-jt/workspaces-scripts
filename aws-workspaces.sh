#!/bin/bash

set -eu

dockerfile=$(mktemp)
trap "rm $dockerfile" EXIT
cat << EOF > $dockerfile
FROM ubuntu:bionic
RUN apt-get update && apt-get install -y wget gnupg2
# https://clients.amazonworkspaces.com/linux-install.html
RUN wget -q -O - https://workspaces-client-linux-public-key.s3-us-west-2.amazonaws.com/ADB332E7.asc | apt-key add -
RUN echo "deb [arch=amd64] https://d3nt0h4h6pmmc4.cloudfront.net/ubuntu bionic main" | tee /etc/apt/sources.list.d/amazon-workspaces-clients.list
RUN apt-get update
RUN apt-get install -y workspacesclient
CMD /opt/workspacesclient/workspacesclient
EOF

docker build -t aws-workspaces - < $dockerfile
xhost +
docker run -it --rm --name aws-workspaces \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$HOME/.aws-workspaces":"/root/.local/share/Amazon Web Services" \
    -e DISPLAY=$DISPLAY \
    aws-workspaces
