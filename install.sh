#!/bin/bash -e

show_help() {
cat << EOF
usage: ${0##*/} [-hv] [-a arn] [-i group,group,...] [-l group,group,...] [-s group] [-p program] [-u "arguments"]
install import_users.sh and authorized_key_commands.

    -h                 display this help and exit
    -v                 verbose mode.

    -a arn             Assume a role before contacting AWS IAM to get users and keys.
                       This can be used if you define your users in one AWS account, while the EC2
                       instance you use this script runs in another.
    -i group,group     Which IAM groups have access to this instance
                       Comma seperated list of IAM groups. Leave empty for all available IAM users
    -l group,group     Give the users these local UNIX groups
                       Comma seperated list
    -s group,group     Specify IAM group(s) for users who should be given sudo privileges, or leave
                       empty to not change sudo access, or give it the value '##ALL##' to have all
                       users be given sudo rights.
                       Comma seperated list
    -p program         Specify your useradd program to use.
                       Defaults to '/usr/sbin/useradd'
    -u "useradd args"  Specify arguments to use with useradd.
                       Defaults to '--create-home --shell /bin/bash'


EOF
}

IAM_GROUPS=""
SUDO_GROUPS=""
LOCAL_GROUPS=""
ASSUME_ROLE=""
USERADD_PROGRAM=""
USERADD_ARGS=""

while getopts :hva:i:l:s: opt
do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        i)
            IAM_GROUPS="$OPTARG"
            ;;
        s)
            SUDO_GROUPS="$OPTARG"
            ;;
        l)
            LOCAL_GROUPS="$OPTARG"
            ;;
        v)
            set -x
            ;;
        a)
            ASSUME_ROLE="$OPTARG"
            ;;
        p)
            USERADD_PROGRAM="$OPTARG"
            ;;
        u)
            USERADD_ARGS="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
    esac
done

tmpdir=$(mktemp -d)

cd "$tmpdir"

git clone https://github.com/soumiks/aws-ec2-ssh.git

cd "$tmpdir/aws-ec2-ssh"

mkdir -p /opt

cp authorized_keys_command.sh /opt/authorized_keys_command.sh
cp import_users.sh /opt/import_users.sh

if [ "${IAM_GROUPS}" != "" ]
then
    echo "IAM_AUTHORIZED_GROUPS=\"${IAM_GROUPS}\"" >> /etc/aws-ec2-ssh.conf
fi

if [ "${SUDO_GROUPS}" != "" ]
then
    echo "SUDOERS_GROUPS=\"${SUDO_GROUPS}\"" >> /etc/aws-ec2-ssh.conf
fi

if [ "${LOCAL_GROUPS}" != "" ]
then
    echo "LOCAL_GROUPS=\"${LOCAL_GROUPS}\"" >> /etc/aws-ec2-ssh.conf
fi

if [ "${ASSUME_ROLE}" != "" ]
then
    echo "ASSUMEROLE=\"${ASSUME_ROLE}\"" >> /etc/aws-ec2-ssh.conf
fi

if [ "${USERADD_PROGRAM}" != "" ]
then
    echo "USERADD_PROGRAM=\"${USERADD_PROGRAM}\"" >> /etc/aws-ec2-ssh.conf
fi

if [ "${USERADD_ARGS}" != "" ]
then
    echo "USERADD_ARGS=\"${USERADD_ARGS}\"" >> /etc/aws-ec2-ssh.conf
fi

echo 'AuthorizedKeysCommand /opt/authorized_keys_command.sh' >> /etc/ssh/sshd_config
echo 'AuthorizedKeysCommandUser nobody' >> /etc/ssh/sshd_config

echo "* * * * * root /opt/import_users.sh" > /etc/cron.d/import_users
chmod 0644 /etc/cron.d/import_users

/opt/import_users.sh

service sshd restart
service cron restart
