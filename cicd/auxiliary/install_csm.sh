#!/usr/bin/bash

remove_rpm()
{
rpm_name=$1
csm_rpm=$(rpm -qa | grep "$rpm_name")
if [ "$csm_rpm" ]; then
    echo "Removing installed $csm_rpm"
    result=$(rpm -e "$csm_rpm" ); if [ "$result" ] ; then echo "error removing rpm $csm_rpm"; else echo "removed rpm $csm_rpm"; fi
else
    echo "No rpm present $rpm_name"
fi
}

remove_conf()
{
ls /etc/csm/
if [ $? -eq 0 ]; then
   echo "remving csm config files"
   rm -rf /etc/csm
else
   echo "no csm conf available"
fi
}

install_rpm()
{
tgt_build=$1
rpm_name=$2
yum install -y $tgt_build/$(curl -s $tgt_build/|grep "$2"| sed 's/<\/*[^>]*>//g'|cut -d' ' -f1)
if [ $? -eq 0 ]; then
    echo "Successfully installed rpm $rpm_name"
else
    echo "failed installation of rpm $rpm_name"
    exit 1
fi
}

run_command()
{
echo "running command : $1"
$1
if [ $? -eq 0 ]; then
    echo "Successfully : $1"
else
    echo "failed : $1"
    exit 1
fi
}

usage()
{
    echo "\
This script will remove existing csm rpms and 
install csm rpms from  target build

Usage:
sh install_csm.sh -t <target build url for EOS>

"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0
        ;;
        -t)
            [ -z "$2" ] &&
                echo "Error: Target build not provided" && exit 1;
            tgt_build="$2"
            shift 2 ;;
        *) echo "Invalid option $1"; usage; exit 1;;
    esac
done

indices=(alerts csmauditlog supportbundle s3-rsys-index alerts-history)
# remove csm rpms
remove_rpm "csm_agent" 
# remove csm conf
remove_conf
#remove consul data
echo "---- deleting data from consul ----"
run_command "/opt/seagate/eos/hare/bin/consul kv delete -recurse eos/base/"
echo "---- deleting elasticsearch indices ----"
for i in "${indices[@]}"
do
  printf "\n--- deleting $i index ---" 
  curl -X DELETE http://localhost:9200/"$i"
done
# install csm rpms  from target build
install_rpm "$tgt_build" "csm_agent"
# setup csm
run_command "csm_setup post_install"
run_command "csm_setup config"
run_command "csm_setup init"
# start csm_agent and csm_web services
run_command "systemctl start csm_agent"

