#!/bin/bash
set -e

# Usage
usage() {
    echo "Usage:"
    echo "    ${0} -h <LDAP_HOST> -u <LDAP_USERDN> -p <LDAP_PASSWORD> -b <LDAP_BASEDN> -f <LDIF FILE>"
    exit 1
}

sleep_time=5
MAX_RETRY=10

while getopts "h:u:p:b:f:" opt; do
  case $opt in
    h)
      ldap_host=${OPTARG}
      ;;
    u)
      ldap_userdn=${OPTARG}
      ;;
    p)
      ldap_password=${OPTARG}
      ;;
    b)
      ldap_base=${OPTARG}
      ;;
    f)
      ldap_file=${OPTARG}
      ;;
    *)
      echo "Invalid parameter(s) or option(s)."
      usage
      ;;
  esac
done

if [ -z "${ldap_host}" ] || [ -z "${ldap_userdn}" ] || [ -z "${ldap_password}" ] || [ -z "${ldap_base}" ] || [ -z "${ldap_file}" ]; then
    echo "Parameters missing"
    usage
fi

echo -e "\n********** Testing LDAP Connection"
until ldapsearch -x -LLL -H "ldap://${ldap_host}" -x -D "${ldap_userdn}" -w "${ldap_password}" -b "${ldap_base}"
do
    echo -e "\n******************** LDAP unavailable, sleeping for ${sleep_time}"
    sleep "${sleep_time}"
done

echo -e "\n********** LDAP available, adding data"
count=1
until [ $count -ge ${MAX_RETRY} ]
do
  ldapadd -H "ldap://${ldap_host}" -c -x -D "${ldap_userdn}" -f "${ldap_file}" -w "${ldap_password}" > /dev/null 2>&1
  status=$?
  [[ ${status} -eq 0  ]] && break
  count=$[$count+1]
  echo -e "\n******************** Error ${status} adding custom configuration, retry ... ${count}\n"
  sleep "${sleep_time}"
done
