yum -y groupinstall 'Development Tools' 
yum -y install pam-devel 
yum -y install opnssl-devel 
yum -y install python 
yum -y install python-devel 
yum -y install libcurl-devel 

# Next download and install the latest version of OMI server v 1.0.8.2
mkdir /root/downloads
cd /root/downloads

wget https://github.com/Azure/azure-linux-extensions/raw/master/DSC/packages/dsc-1.0.0-320.ssl_100.rpm
wget https://github.com/Azure/azure-linux-extensions/raw/master/DSC/packages/omiserver-1.0.8.ssl_100.rpm

yum -y localinstall omiserver-1.0.8.ssl_100.rpm

# Next download and install the latest PSDSC for Linux v 1.1.0-466, at the time of this post
cd /root/downloads
yum -y localinstall dsc-1.0.0-320.ssl_100.rpm
 
