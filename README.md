一、下载依赖包：

机器要联网
sudo yum install --downloadonly --downloaddir=./ansible ansible
下载ansible的依赖包。
不同机器环境需要的依赖包可能不一样，需要根据需要下载相应的依赖包。

安装依赖包：
cd ansible_pkg/
rpm -Uvh *.rpm --nodeps --force

确认 ansible 是否安装成功
ansible --version

确认 jinja2 是否安装成功
pip show jinja2

确认 jmespath 是否安装成功
pip show jmespath

二、编译 TiDB arm 版本
编译过程需要联网下载依赖,需要能够访问google等网站。
install.sh
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



执行./install.sh

由于之前的机器不能访问google.golang等机器，所以部分编译失败，后来都是按各条命令单独执行的。

编译tidb的时候报bigfft的函数missing body错误，解决方案，将https://github.com/remyoudompheng/bigfft fork到自己的github上加上函数体，
tidb下的go.mod 里的链接替换为自己的https://github.com/wuzk/bigfft

编译tikv的时候报cmake报版本需要3.10以上，当前版本是2.8.12
卸载当前版本，下载编译安装3.12版本:
yum remove cmake

wget https://cmake.org/files/v3.12/cmake-3.12.0-rc1.tar.gz

tar -zxvf cmake-3.12.0-rc1.tar.gz 
cd cmake-3.12.0-rc1/
./bootstrap 
gmake
gmake install
cmake --version

新版本的cmake需要添加到环境变量中
vi /etc/profile
添加
export PATH=$JAVA_HOME/bin:$JRE_HOME/bin:/usr/local/bin:$PATH
source /etc/profile

编译tispark的时候缺报，因为是jar，直接从其他环境拷贝过来就tispark-SNAPSHOT-jar-with-dependencies.jar

编译完成后的列表：



三、安装tidb

1.下载 tidb-ansible 以及完成相关初始化
  1)在中控机上创建 tidb 用户，并生成 ssh key
  2)安装git  yum install git
  3)在下载机上下载 TiDB-Ansible 及 TiDB 安装包，但下载机不需要安装 ansible，具体操作如下：
     下载 release-3.0 版本：
     git clone -b v3.0.0 https://github.com/pingcap/tidb-ansible.git
注：不需要执行 ansible-playbook local_prepare.yml，因为使用的是自己编译的 ARM 版二进制包
4)  在中控机上配置部署机器 ssh 互信及 sudo 规则
5) 在部署目标机器上安装 NTP 服务
6) 在部署目标机器上配置 CPUfreq 调节器模式
创建/data1/deploy目录并将权限赋给tidb用户

2.部署任务：

在 tidb-ansible 目录下创建 resources/bin/ 目录，并且把编译的 ARM 版二进制文件全部放到 resources/bin/ 目录

在 tidb-ansible 目录下创建 downloads目录，把
grafana-6.1.6.tar.gz  spark-2.3.2-bin-hadoop2.7.tgz拷贝进去。

 编辑 inventory.ini
## TiDB Cluster Part
[tidb_servers]
192.168.1.1

[tikv_servers]
192.168.1.1

[pd_servers]
192.168.1.1

[spark_master]

[spark_slaves]

[lightning_server]

[importer_server]

## Monitoring Part
# prometheus and pushgateway servers
[monitoring_servers]
192.168.1.1

[grafana_servers]
192.168.1.1

# node_exporter and blackbox_exporter servers
[monitored_servers]
192.168.1.1

[alertmanager_servers]
192.168.1.1

[kafka_exporter_servers]

## Binlog Part
[pump_servers]

[drainer_servers]

## Group variables
[pd_servers:vars]
# location_labels = ["zone","rack","host"]

## Global variables
[all:vars]
deploy_dir = /data1/deploy

## Connection
# ssh via normal user
ansible_user = tidb

cluster_name = test-cluster

tidb_version = v3.0.0

# process supervision, [systemd, supervise]
process_supervision = systemd

timezone = Asia/Shanghai

enable_firewalld = False
# check NTP service
enable_ntpd = True
set_hostname = False

## binlog trigger
enable_binlog = False

# kafka cluster address for monitoring, example:
# kafka_addrs = "192.168.0.11:9092,192.168.0.12:9092,192.168.0.13:9092"
kafka_addrs = ""

# zookeeper address of kafka cluster for monitoring, example:
# zookeeper_addrs = "192.168.0.11:2181,192.168.0.12:2181,192.168.0.13:2181"
zookeeper_addrs = ""

# enable TLS authentication in the TiDB cluster
enable_tls = False

# KV mode
deploy_without_tidb = False

# wait for region replication complete before start tidb-server.
wait_replication = True

# Optional: Set if you already have a alertmanager server.
# Format: alertmanager_host:alertmanager_port
alertmanager_target = ""

grafana_admin_user = "admin"
grafana_admin_password = "admin"


### Collect diagnosis
collect_log_recent_hours = 2

enable_bandwidth_limit = True
# default: 10Mb/s, unit: Kbit/s
collect_bandwidth_limit = 10000


3.初始化系统环境，修改内核参数
   执行前需要调整ansible.cfg 的timeout = 60 默认是10

  修改/home/tidb/tidb-ansible/roles/check_system_static/tasks/main.yml去掉，屏蔽掉：
- name: Deploy epollexclusive script
  copy: src="{{ script_dir }}/check/epollexclusive" dest="{{ deploy_dir }}/epollexclusive" mode=0755

- name: Preflight check - Check if the operating system supports EPOLLEXCLUSIVE
  shell: "{{ deploy_dir }}/epollexclusive"
  register: epollexclusive_check

- name: Clean epollexclusive script
  file: path={{ deploy_dir }}/epollexclusive state=absent

- name: Preflight check - Fail when epollexclusive is unavailable
  fail:
    msg: "The current machine may be a docker virtual machine, and the corresponding physical machine operating system does not support epollexclusive"
  when: epollexclusive_check.stdout.find("True") == -1

使用开发模式启动
   #ansible-playbook bootstrap.yml

ansible-playbook bootstrap.yml  --extra-vars "dev_mode=true"
         
 

4.部署 TiDB 集群软件

  修改deploy.yml, 屏蔽掉以下内容
  
- name: deploying diagnostic tools
  hosts: monitored_servers
  tags:
    - collect_diagnosis
  roles:
    - collect_diagnosis

这块只屏蔽掉 - grafana_collector
- name: deploying grafana
  hosts: grafana_servers
  tags:
    - grafana
  roles:
    - grafana
    - grafana_collector



  ansible-playbook deploy.yml
        
 5. 启动 TiDB 集群

修改start.yml 屏蔽掉以下内容： 

 - name: start grafana_collector by supervise
      shell: cd {{ deploy_dir }}/scripts && ./start_{{ item }}.sh
      when: process_supervision == 'supervise'
      with_items:
        - grafana_collector

    - name: start grafana_collector by systemd
      systemd: name=grafana_collector-{{ grafana_collector_port }}.service state=started enabled=no
      when: process_supervision == 'systemd'
      become: true

    - name: wait until the grafana_collector port is up
      wait_for:
        host: "{{ ansible_host }}"
        port: "{{ grafana_collector_port }}"
        state: started
        msg: "the grafana_collector port {{ grafana_collector_port }} is not up"


       ansible-playbook start.yml
