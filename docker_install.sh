#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

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

mirror=''
Default_Download_Url=""

Docker_Download_Url_Check() {
    ser_names=(download.docker.com mirrors.aliyun.com/docker-ce mirror.azure.cn/docker-ce)
    tmp_file1=/dev/shm/net_test1.pl
    [ -f "${tmp_file1}" ] && rm -f ${tmp_file1}
	touch $tmp_file1

    for ser_name in ${ser_names[@]};
	do
		NODE_CHECK=$(curl -s 2>/dev/null -w "%{http_code} %{time_total}" https://${ser_name} -o c${ser_name}.txt|xargs)
		rm -rf c${ser_name}.txt
		NODE_STATUS=$(echo ${NODE_CHECK}|awk '{print $1}')
		TIME_TOTAL=$(echo ${NODE_CHECK}|awk '{print $2 * 1000 - 500 }'|cut -d '.' -f 1)
		if [ "${NODE_STATUS}" == "200" ] || [ "${NODE_STATUS}" == "301" ] || [ "${NODE_STATUS}" == "403" ];then
			if [ $TIME_TOTAL -lt 100 ];then
				echo "$ser_name" >> $tmp_file1
			fi
		fi
	done
    NODE_URL=$(cat $tmp_file1|sort -r -g -t " " -k 1|head -n 1|awk '{print $1}')

	rm -f $tmp_file1
    mirror="$NODE_URL"
    case "$mirror" in
    mirrors.aliyun.com/docker-ce)
        mirror="Aliyun"
        ;;
    mirror.azure.cn/docker-ce)
        mirror="AzureChinaCloud"
        ;;
    *)
        mirror=""
        ;;
    esac
}

Docker_Download_Url_Check

case "$mirror" in
Aliyun)
    Default_Download_Url="https://mirrors.aliyun.com/docker-ce"
    ;;
AzureChinaCloud)
    Default_Download_Url="https://mirror.azure.cn/docker-ce"
    ;;
*)
    Default_Download_Url="https://download.docker.com"
    ;;
esac

DEFAULT_REPO_FILE="docker-ce.repo"

if [ -z "$REPO_FILE" ]; then
    REPO_FILE="$DEFAULT_REPO_FILE"
fi

Command_Exists() {
    command -v "$@" >/dev/null 2>&1
}

Get_Distribution() {
    lsb_dist=""
    lsb_name=""

    if [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
        lsb_name="$(. /etc/os-release && echo "$NAME")"
    fi
    echo "$lsb_dist $lsb_name"
}

Docker_Stop() {
    if Command_Exists docker || [ -e /var/run/docker.sock ] || [ -f /lib/systemd/system/docker.service ]; then
        if which systemctl; then
            systemctl stop docker
            systemctl stop docker.socket
        else
            service docker stop
        fi
    fi
}

Docker_Start() {
    if Command_Exists docker || [ -f /lib/systemd/system/docker.service ]; then
        if which systemctl; then
            systemctl stop docker
            systemctl stop docker.socket
            systemctl stop getty@tty1.service
            # if [ $is_docker == "1"];then
            #     mv /etc/docker/daemon.json /root/
            # fi
            systemctl mask getty@tty1.service
            systemctl enable docker
            systemctl reset-failed docker.service
            systemctl start docker.service
            if [ "$?" != "0" ];then
                cat /etc/docker/daemon.json
            fi
        else
            chkconfig --add docker
            chkconfig --level 2345 docker on
            service docker start
        fi
    fi
}

Docker_Remove() {
    pkgs="docker-ce docker-ce-cli containerd.io"
    pkgs_01="docker docker-common docker-selinux docker-engine docker-client"
    pkgs_02="docker-client-latest docker-latest docker-latest-logrotate docker-logrotate"
    set +e

    if Command_Exists docker || [ -e /var/run/docker.sock ] || [ -f /lib/systemd/system/docker.service ]; then
        if [ -f "/usr/bin/apt-get" ]; then
            apt-get remove $pkgs -y
        elif [ -f "/usr/bin/yum" ]; then
            systemctl disable docker
            yum remove $pkgs_01 -y
            yum remove $pkgs_02 -y
            yum remove $pkgs -y
            rm -rf /etc/yum.repos.d/docker-ce.repo
        fi
        if [ -f /var/run/docker.sock ];then
            rm -rf /var/run/docker.sock*
        fi
    fi
    if [ -f /usr/bin/docker-compose ]; then
        rm -rf /usr/bin/docker-compose
    fi
    if [ -f /usr/local/bin/docker-compose ]; then
        rm -rf /usr/local/bin/docker-compose
    fi
}

Is_Darwin() {
    case "$(uname -s)" in
    *darwin*) true ;;
    *Darwin*) true ;;
    *) false ;;
    esac
}

Check_Forked() {
    if Command_Exists lsb_release; then
        set +e
        lsb_release -a -u >/dev/null 2>&1
        lsb_release_exit_code=$?

        if [ "$lsb_release_exit_code" = "0" ]; then
            cat <<-EOF
You're using '$lsb_dist' version '$dist_version'.
EOF
            lsb_dist=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'id' | cut -d ':' -f 2 | tr -d '[:space:]')
            dist_version=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'codename' | cut -d ':' -f 2 | tr -d '[:space:]')
            cat <<-EOF
Upstream release is '$lsb_dist' version '$dist_version'.
EOF
        else
            if [ -r /etc/debian_version ] && [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "raspbian" ]; then
                if [ "$lsb_dist" = "osmc" ]; then
                    lsb_dist=raspbian
                else
                    lsb_dist=debian
                fi
                dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
                case "$dist_version" in
                11)
                    dist_version="bullseye"
                    ;;
                10)
                    dist_version="buster"
                    ;;
                9)
                    dist_version="stretch"
                    ;;
                8)
                    dist_version="jessie"
                    ;;
                esac
            fi
        fi
    fi
}

Init_Docker_Manager() {
    docker_db="/www/server/panel/data/docker.db"
    is_docker=""

    if [ ! -f $docker_db ] || [ ! -s $docker_db ]; then
        wget -O $docker_db $download_Url/install/src/docker.db
    fi

    if Command_Exists docker || [ -e /var/run/docker.sock ] || [ -f /lib/systemd/system/docker.service ]; then
        is_docker="1"
    fi
    echo "$is_docker"
}

Pip_Install() {
    if [ -f /usr/bin/btpip ]; then
        btpip install pytz
        btpip install docker
    else
        pip install pytz
        pip install docker
    fi
}

Docker_Install() {
    lsb_dist=$(Get_Distribution|awk -F " " '{print $1}')
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

    case "$lsb_dist" in
    ubuntu)
        if Command_Exists lsb_release; then
            dist_version="$(lsb_release --codename | cut -f2)"
        fi
        if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
            dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
        fi
        ;;
    debian | raspbian)
        dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
        case "$dist_version" in
        11)
            dist_version="bullseye"
            ;;
        10)
            dist_version="buster"
            ;;
        9)
            dist_version="stretch"
            ;;
        8)
            dist_version="jessie"
            ;;
        esac
        ;;
    centos | rhel | sles | ol | tencentos | alinux | anolis | rocky | euleros | almalinux)
        if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
            dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
        fi
        ;;
    *)
        if Command_Exists lsb_release; then
            dist_version="$(lsb_release --release | cut -f2)"
        fi
        if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
            dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
        fi
        ;;
    esac

    Check_Forked

    case "$lsb_dist" in
    ubuntu | debian | raspbian)
        docker_gpg="/usr/share/keyrings/docker-archive-keyring.gpg"
        apt_repo_file="/etc/apt/sources.list.d/docker.list"
        pre_reqs="apt-transport-https ca-certificates curl"

        if ! command -v gpg >/dev/null; then
            pre_reqs="$pre_reqs gnupg"
        fi

        apt_repo="deb [arch=$(dpkg --print-architecture) signed-by=$docker_gpg] $Default_Download_Url/linux/$lsb_dist $dist_version stable"
        (
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y $pre_reqs
            if [ -f $docker_gpg ] && [ -f $apt_repo_file ]; then
                rm -rf $docker_gpg
                rm -rf $apt_repo_file
            fi
            curl -fsSL --connect-time 10 --retry 5 $Default_Download_Url/linux/$lsb_dist/gpg | gpg --dearmor --yes -o $docker_gpg
            echo "$apt_repo" > $apt_repo_file
            apt-get update
        )
        pkg_version=""
        (
            pkgs="$pkgs docker-ce${pkg_version%=}"
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $pkgs
        )
        ;;
    centos | fedora | rhel | ol | tencentos | alinux | anolis | rocky | almalinux)
        if [ "$(uname -m)" != "s390x" ] && [ "$lsb_dist" = "rhel" ]; then
            echo "Packages for RHEL are currently only available for s390x."
            exit 1
        fi
        yum_repo="$Default_Download_Url/linux/$lsb_dist/$REPO_FILE"
        if [ "$lsb_dist" == "ol" ] || [ "$lsb_dist" == "tencentos" ] || [ "$lsb_dist" == "alinux" ] || [ "$lsb_dist" == "anolis" ]; then
            yum_repo="$Default_Download_Url/linux/centos/$REPO_FILE"
        fi
        if [ "$lsb_dist" == "rocky" ] || [ "$lsb_dist" == "almalinux" ]; then
            yum_repo="$Default_Download_Url/linux/centos/$REPO_FILE"
        fi
        if ! curl -Ifs "$yum_repo" >/dev/null; then
            echo "Error: Unable to curl repository file $yum_repo, is it valid?"
            exit 1
        fi
        if [ "$lsb_dist" = "fedora" ]; then
            pkg_manager="dnf"
            config_manager="dnf config-manager"
            enable_channel_flag="--set-enabled"
            disable_channel_flag="--set-disabled"
            pre_reqs="dnf-plugins-core"
            pkg_suffix="fc$dist_version"
        else
            pkg_manager="yum"
            config_manager="yum-config-manager"
            enable_channel_flag="--enable"
            disable_channel_flag="--disable"
            pre_reqs="yum-utils"
            pkg_suffix="el"
        fi
        (
            $pkg_manager install -y $pre_reqs
            $config_manager --add-repo $yum_repo
            $pkg_manager makecache
        )
        lsb_name=$(Get_Distribution|awk -F " " '{print $3}')
        if [ "$lsb_name" = "Stream" ] || [ "$lsb_dist" = "alinux" ] || [ "$lsb_dist" = "anolis" ];then
            conflicting="--allowerasing"
        fi
        if [ "$lsb_name" = "rocky" ] || [ "$lsb_dist" = "euleros" ] || [ "$lsb_dist" = "almalinux" ];then
            conflicting="--allowerasing"
        fi
        pkg_version=""
        (
            pkgs_01="atomic-registries container-storage-setup containers-common"
            pkgs_02="oci-register-machine oci-systemd-hook oci-umount python-pytoml subscription-manager-rhsm-certificates yajl"
            $pkg_manager install -y docker-ce$pkg_version lvm2 device-mapper-persistent-data $conflicting
            $pkg_manager install -y -q $pkgs_01
            $pkg_manager install -y -q $pkgs_02
        )
        ;;
    euleros)
        if [ "$(uname -m)" != "s390x" ] && [ "$lsb_dist" = "rhel" ]; then
            echo "Packages for RHEL are currently only available for s390x."
            exit 1
        fi
        cd /www
        pkg_manager="yum"
        $pkg_manager install -y docker* --skip-broken
        ;;
    sles)
        if [ "$(uname -m)" != "s390x" ]; then
            echo "Packages for SLES are currently only available for s390x"
            exit 1
        fi

        sles_version="${dist_version##*.}"
        sles_repo="$Default_Download_Url/linux/$lsb_dist/$REPO_FILE"
        opensuse_repo="https://download.opensuse.org/repositories/security:SELinux/SLE_15_SP$sles_version/security:SELinux.repo"
        if ! curl -Ifs "$sles_repo" >/dev/null; then
            echo "Error: Unable to curl repository file $sles_repo, is it valid?"
            exit 1
        fi
        pre_reqs="ca-certificates curl libseccomp2 awk"
        (
            zypper install -y $pre_reqs
            zypper addrepo $sles_repo
            zypper addrepo $opensuse_repo
            zypper --gpg-auto-import-keys refresh
            zypper lr -d
        )
        pkg_version=""
        (
            zypper install -y docker-ce$pkg_version
        )
        ;;
    *)
        if [ -z "$lsb_dist" ]; then
            if Is_Darwin; then
                echo
                echo "ERROR: Unsupported operating system 'macOS'"
                echo
                exit 1
            fi
        fi
        echo
        echo "ERROR: Unsupported distribution '$lsb_dist'"
        echo
        exit 1
        ;;
    esac
}

Docker_Compose_Install() {
    Compose_Download_Url="$download_Url/install/src/docker-compose-$(uname -s)-$(uname -m)"
    Compose_Path="/usr/local/bin/docker-compose"
    Compose_lin="/usr/bin/docker-compose"

    if [ ! -f $Compose_Path ]; then
        curl -fsSL --connect-time 5 --retry 3 $Compose_Download_Url -o $Compose_Path
        chmod +x $Compose_Path
        rm -rf $Compose_lin
        ln -s $Compose_Path $Compose_lin
    fi
}

Docker_Uninstall() {
    Docker_Stop
    Docker_Remove

    if [ -h "/var/lib/docker" ]; then
        rm -rf /var/lib/docker
    fi
}
if [ "${1}" == 'install' ]; then
    set +e
    Init_Docker_Manager
    if [ "$is_docker" != "1" ];then
        Docker_Install
    fi
    Docker_Compose_Install
    Pip_Install
    Docker_Start
elif [ "${1}" == 'uninstall' ]; then
    Docker_Uninstall
fi
