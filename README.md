写在前面:

编译的环境centos7.5
本文档包含了编译时需要的包（ansible_pkg）,编译后的文件（build），和其他的包（downloads）
将（fio）下面的包复制到tikv机器的/usr/lib64目录下
由于编译后的文件太大，无法上传到git，上传到了百度网盘上连接地址：
https://pan.baidu.com/s/1ymWZWrDzY66FJVLS9WxPzQ

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
## TiDB Cluster Part
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


3.初始化系统环境，修改内核参数
   执行前需要调整ansible.cfg 的timeout = 60 默认是10

  修改/home/tidb/tidb-ansible/roles/check_system_static/tasks/main.yml去掉，屏蔽掉：
- name: Deploy epollexclusive script
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
