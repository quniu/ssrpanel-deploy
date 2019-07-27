### 适用环境
- Centos6+
- Debian8+
- Ubuntu16+



### 功能
- 安装shadowsocksr服务端
- 卸载shadowsocksr服务端
- 安装v2ray
- 卸载v2ray
- 设置定时重启服务器
- 时区校正`Asia/Shanghai`

### 安装wget
```
# Centos
yum -y install wget

# Ubuntu，Debian
apt-get -y install wget
```

### 执行脚本
```
wget -N --no-check-certificate https://raw.githubusercontent.com/quniu/ssrpanel-deploy/master/deploy.sh
chmod +x deploy.sh
./deploy.sh
```

### 说明
- 日志目录`/root/`
- 脚本目录`/root/`下面
- SSR安装目录`/usr/local/shadowsocksr`
- ssrpanel-v2ray安装目录`/usr/local/ssrpanel-v2ray`
- v2ray安装目录`/usr/local/ssrpanel-v2ray/xxxxx`，xxxxx是版本号

安装的版本均是最新版本


### 查看shadowsocksr服务

默认安装成功之后会自动启动服务

其他服务命令

centos使用`service`,ubantu使用`/etc/init.d/v2ray`,

SSR
```
# status start stop
/etc/init.d/shadowsocksr status
```

v2ray
```
# status start stop
/etc/init.d/v2ray status
```


### 注意
安装过程会要求填写或者确认某些数据，请认真看清楚！！！！！

一下是数据库默认信息

- 数据库ip，默认`127.0.0.1`
- 数据库端口，默认`3306`
- 数据库名，默认`ssrpanel`
- 数据库用户名，默认`ssrpanel`
- 数据库密码，默认`password`

##### 以下是针对v2ray

- 额外ID，既`alter-id`（面板上的额外ID），默认`16`
- 端口号，既`v2ray_vmess_port`（面板上的端口号） ，默认`52099`
- 系统，既`v2ray_sys` ，默认`linux`
- 操作系统位数，既`v2ray_arc` ，默认`64`

注意：目前v2ray只配置部署`TCP`模式，后期会加上其他模式

### 开启bbr

使用root用户运行以下命令：

```
wget --no-check-certificate https://github.com/quniu/servertool/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh
```
安装完成后，脚本会提示需要重启 VPS，输入 y 并回车后重启。

重启完成后，进入 VPS，验证一下是否成功安装最新内核并开启 TCP BBR，输入以下命令：

```
uname -r
```
查看内核版本，显示为最新版就表示 OK 了


##### 查看是否启动

```
lsmod | grep bbr
```
返回值是tcp_bbr模块，即说明 bbr 已启动。

注意：并不是所有的 VPS 都会有此返回值，若没有也属正常。

### 测速
```
wget https://raw.github.com/sivel/speedtest-cli/master/speedtest.py
chmod +x speedtest.py
python speedtest.py
```

如需图
```
python speedtest.py --share
```
会生成一张测速图

### 建议

先创建节点获取到ID再去部署SSR和v2ray服务，原因如下
- SSR创建节点时需要用到node ID，这个node ID是在后台节点列表里ID选项对应的ID值
- v2ray创建节点时需要用到node ID 、端口号、额外ID这些信息

仅供个人参考学习，请勿用于商业活动
