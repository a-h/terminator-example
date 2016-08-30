# Install terraform
wget -nv -nc https://releases.hashicorp.com/terraform/0.7.2/terraform_0.7.2_linux_amd64.zip
sudo yum install -y unzip
unzip terraform_0.7.2_linux_amd64.zip
sudo mv terraform /usr/local/bin
rm terraform_0.7.2_linux_amd64.zip
# Install awscli
sudo yum install -y python-setuptools
sudo easy_install pip
sudo pip install awscli
# Ensure that the clock is set properly.
# Sync the time
sudo yum install -y ntp
sudo chkconfig ntpd on
sudo ntpdate pool.ntp.org
sudo service ntpd start