#!/bin/bash -ex
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
# sudo yum update -y
sudo yum install -y git
wget -nv https://storage.googleapis.com/golang/go1.7.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.7.linux-amd64.tar.gz
sudo bash -c 'echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile.d/go-tools.sh'
source /etc/profile.d/go-tools.sh

# Setup workspace.
echo "Creating git directory" $HOME/work/
mkdir -p $HOME/work
export GOPATH=$HOME/work

go get github.com/a-h/version
cd $GOPATH/src/github.com/a-h/version
go generate
go build ./...
./version