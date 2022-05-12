#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

install_tmp='/tmp/bt_install.pl'

grep "English" /www/server/panel/config/config.json
if [ "$?" -ne 0 ]; then
    public_file=/www/server/panel/install/public.sh
    if [ ! -f $public_file ]; then
        wget -O $public_file http://download.bt.cn/install/public.sh -T 5
    fi
    . $public_file
    download_Url=$NODE_URL
else
    download_Url="https://node.aapanel.com"
fi
echo $download_Url

Install_Docker() {
    if [ ! -d /www/server/panel/plugin/docker ]; then
        Docker_Install_File="/www/server/panel/install/docker_install.sh"
        mkdir -p /www/server/panel/plugin/docker
        echo '正在安装脚本文件...' >$install_tmp

        grep "English" /www/server/panel/config/config.json
        if [ "$?" -ne 0 ]; then
            wget -O /www/server/panel/plugin/docker/docker_main.py $download_Url/install/plugin/docker/docker_main.py -T 5
            wget -O /www/server/panel/plugin/docker/index.html $download_Url/install/plugin/docker/index.html -T 5
            wget -O /www/server/panel/plugin/docker/info.json $download_Url/install/plugin/docker/info.json -T 5
            wget -O /www/server/panel/plugin/docker/icon.png $download_Url/install/plugin/docker/icon.png -T 5
            wget -O /www/server/panel/plugin/docker/login-docker.html $download_Url/install/plugin/docker/login-docker.html -T 5
            wget -O /www/server/panel/plugin/docker/userdocker.html $download_Url/install/plugin/docker/userdocker.html -T 5
        else
            wget -O /www/server/panel/plugin/docker/docker_main.py $download_Url/install/plugin/docker_en/docker_main.py -T 5
            wget -O /www/server/panel/plugin/docker/index.html $download_Url/install/plugin/docker_en/index.html -T 5
            wget -O /www/server/panel/plugin/docker/info.json $download_Url/install/plugin/docker_en/info.json -T 5
            wget -O /www/server/panel/plugin/docker/icon.png $download_Url/install/plugin/docker_en/icon.png -T 5
            wget -O /www/server/panel/plugin/docker/login-docker.html $download_Url/install/plugin/docker_en/login-docker.html -T 5
            wget -O /www/server/panel/plugin/docker/userdocker.html $download_Url/install/plugin/docker_en/userdocker.html -T 5
        fi

        wget -O $Docker_Install_File $download_Url/install/0/docker_install.sh -T 5
        . $Docker_Install_File install
        rm -rf $Docker_Install_File

        echo '安装完成' >$install_tmp
    fi
}

Upload_Docker() {
    echo '正在安装脚本文件...' >$install_tmp
    grep "English" /www/server/panel/config/config.json
    if [ "$?" -ne 0 ]; then
        wget -O /www/server/panel/plugin/docker/docker_main.py $download_Url/install/plugin/docker/docker_main.py -T 5
        wget -O /www/server/panel/plugin/docker/index.html $download_Url/install/plugin/docker/index.html -T 5
        wget -O /www/server/panel/plugin/docker/info.json $download_Url/install/plugin/docker/info.json -T 5
        wget -O /www/server/panel/plugin/docker/icon.png $download_Url/install/plugin/docker/icon.png -T 5
        wget -O /www/server/panel/plugin/docker/login-docker.html $download_Url/install/plugin/docker/login-docker.html -T 5
        wget -O /www/server/panel/plugin/docker/userdocker.html $download_Url/install/plugin/docker/userdocker.html -T 5
    else
        wget -O /www/server/panel/plugin/docker/docker_main.py $download_Url/install/plugin/docker_en/docker_main.py -T 5
        wget -O /www/server/panel/plugin/docker/index.html $download_Url/install/plugin/docker_en/index.html -T 5
        wget -O /www/server/panel/plugin/docker/info.json $download_Url/install/plugin/docker_en/info.json -T 5
        wget -O /www/server/panel/plugin/docker/icon.png $download_Url/install/plugin/docker_en/icon.png -T 5
        wget -O /www/server/panel/plugin/docker/login-docker.html $download_Url/install/plugin/docker_en/login-docker.html -T 5
        wget -O /www/server/panel/plugin/docker/userdocker.html $download_Url/install/plugin/docker_en/userdocker.html -T 5
    fi
    echo '更新完成' >$install_tmp
}

Uninstall_Docker() {
    pkgs="docker-ce docker-ce-cli containerd.io"
    pkgs_01="docker docker-common docker-selinux docker-engine docker-client"
    pkgs_02="docker-client-latest docker-latest docker-latest-logrotate docker-logrotate"

    rm -rf /www/server/panel/plugin/docker
    if [ -h "/var/lib/docker" ]; then
        rm -rf /var/lib/docker
    fi
    rm -rf /etc/yum.repos.d/docker-ce.repo
    if [ -f "/usr/bin/apt-get" ]; then
        systemctl stop docker
        apt-get purge $pkgs -y
    elif [ -f "/usr/bin/yum" ]; then
        if [ -f /usr/bin/systemctl ]; then
            systemctl disable docker
            systemctl stop docker
        else
            service docker stop
            chkconfig --level 2345 docker off
            chkconfig --del docker
        fi
        yum remove $pkgs_01 -y
        yum remove $pkgs_02 -y
        yum remove $pkgs -y
    fi
    rm -rf /usr/bin/docker-compose
    rm -rf /usr/local/bin/docker-compose

    echo '卸载成功'
}

if [ "${1}" == 'install' ]; then
    Install_Docker
elif [ "${1}" == 'update' ]; then
    Upload_Docker
elif [ "${1}" == 'uninstall' ]; then
    Uninstall_Docker
fi
