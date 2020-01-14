#!/bin/bash
# Soft Version
# TiDN Core
tidb_version=v3.0.0
# TiDB Tools
tispark_version=master
dm_version=master
# Monitor
prometheus_version=v2.8.1
alertmanager_version=v0.17.0
node_exporter_version=v0.17.0
# blackbox_exporter_version=v0.12.0
#v0.12.0 meets some wrong
blackbox_exporter_version=master
pushgateway_version=v0.7.0
grafana_version=6.1.6

# Soft Dir
declare -A soft_srcs

soft_srcs=(
# ["tidb"]="$tidb_version https://github.com/pingcap/tidb.git"
# ["pd"]="$tidb_version https://github.com/pingcap/pd.git"
# ["tikv"]="$tidb_version https://github.com/tikv/tikv.git"
#   ["tispark"]="$tidb_version https://github.com/pingcap/tispark"
  ["tidb-binlog"]="$tidb_version https://github.com/pingcap/tidb-binlog"
["dm"]="$dm_version https://github.com/pingcap/dm"
["prometheus"]="$prometheus_version https://github.com/prometheus/prometheus.git"
["alertmanager"]="$alertmanager_version https://github.com/prometheus/alertmanager.git"
["node_exporter"]="$node_exporter_version https://github.com/prometheus/node_exporter.git"
["blackbox_version"]="$blackbox_exporter_version https://github.com/prometheus/blackbox_exporter.git"
["pushgateway"]="$pushgateway_version https://github.com/prometheus/pushgateway.git"
# ["grafana"]="$grafana_version https://github.com/grafana/grafana.git"
)

# Dir
ROOT=$PWD/build
target=$ROOT/bin
rm -rf $ROOT
mkdir -p $target

sudo yum install -y gcc gcc-c++ wget git zlib-devel

cd $ROOT
# Go
if which go >/dev/null; then
   echo "go installed, skip"
else
   wget https://dl.google.com/go/go1.12.6.linux-arm64.tar.gz
   sudo tar -C /usr/local -xzf go1.12.6.linux-arm64.tar.gz
   echo "export GOPATH=$ROOT/go" >> ~/.bashrc
   echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc
   source ~/.bashrc
fi

# Rust
if which rustc >/dev/null; then
   echo "rust installed, skip"
else
   curl https://sh.rustup.rs -sSf | sh -s -- -y
   source $HOME/.cargo/env
fi

# Install cmake3
if which cmake3 >/dev/null; then
   echo "cmake3 installed, skip"
else
   wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

   sudo rpm -ivh epel-release-latest-7.noarch.rpm
   sudo yum install -y epel-release
   sudo yum install -y cmake3

   sudo ln -s /usr/bin/cmake3 /usr/bin/cmake
fi

# Install Java
if which java >/dev/null;then
echo "java installed, skip"
else
ce $ROOT
wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u141-b15/336fa29ff2bb4ef291e347e091f7f4a7/jdk-8u141-linux-arm64-vfp-hflt.tar.gz"
sudo tar -C /usr/local -xzf jdk-8u141-linux-arm64-vfp-hflt.tar.gz
echo 'export JAVA_HOME=/usr/local/jdk1.8.0_141' >> ~/.bashrc
echo 'export JRE_HOME=/user/local/jdk1.8.0_141/jre' >> ~/.bashrc
echo 'export PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin' >> ~/.bashrc
fi


# Install maven
if which mvn >/dev/null;then
echo "maven installed, skip"
else
wget https://mirrors.tuna.tsinghua.edu.cn/apache/maven/maven-3/3.6.1/binaries/apache-maven-3.6.1-bin.tar.gz
sudo tar -C /usr/local -xzf apache-maven-3.6.1-bin.tar.gz
echo 'export PATH=$PATH:/usr/local/apache-maven-3.6.1/bin' >> ~/.bashrc
source ~/.bashrc
fi


# # RocksDB gflags
# git clone https://github.com/gflags/gflags.git
# cd gflags
# git checkout v2.0
# ./configure --build=aarch64-unknown-linux-gnu && make && sudo make install
# cd $ROOT

# Build Monitor
for soft in $(echo ${!soft_srcs[*]})
do
soft_src=${soft_srcs[$soft]}
cd $ROOT
git clone -b $soft_src
cd $soft
make build
if [ -d bin ];then
cp bin/* $target
else
cp $soft $target
fi
cd $ROOT
echo "`date +'%F %T'`: Build Soft $soft done ."
done

# Download Grafana
cd $ROOT
wget https://dl.grafana.com/oss/release/grafana-${grafana_version}.linux-arm64.tar.gz
tar -zxvf grafana-${grafana_version}.linux-arm64.tar.gz

cp grafana-${grafana_version}/bin/* bin/

# Build TiDB
cd $ROOT
git clone -b $tidb_version https://github.com/pingcap/tidb
cd tidb
make
cp bin/* $target
# Build PD
cd $ROOT
git clone -b $tidb_version https://github.com/pingcap/pd
cd pd
make
cp bin/* $target

# Build TiKV
cd $ROOT
git clone -b $tidb_version https://github.com/tikv/tikv.git
cd tikv
ROCKSDB_SYS_SSE=0 make release
cp target/release/tikv-*  $target

# Build tispark
cd $ROOT
git clone -b $tispark_version https://github.com/pingcap/tispark
cd tispark
mvn clean install -Dmaven.test.skip=true -P spark-2.3
