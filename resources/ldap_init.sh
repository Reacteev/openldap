#!/bin/bash

set -e

LDAP_USER_DN="cn=admin,${SLAPD_FULL_DOMAIN}"
LDAP_PASSWORD=${SLAPD_PASSWORD}
LDAP_BASE_DN=${SLAPD_FULL_DOMAIN}
SLAPD_LDIF_BASE="${SLAPD_LDIF_BASE:-/var/tmp/ldifs}"
SLAPD_LOAD_LDIFS=$1
HOSTNAME=$(cat /etc/hostname)
TMP_ENVS="/tmp/env_tmp"

echo "List of ldifs to load : $SLAPD_LOAD_LDIFS"

OLD_IFS=$IFS
IFS=","; declare -a ldifs=($SLAPD_LOAD_LDIFS)
IFS=$OLD_IFS

for ldif in "${ldifs[@]}"; do
    echo "Loading ldif : $ldif"
    LDAP_LDIFF="${SLAPD_LDIF_BASE}/${ldif}"
    if [ -r /run/secrets/$ldif ] && [ ! -r $LDAP_LDIFF ]
    then
      cp -a /run/secrets/$ldif $LDAP_LDIFF
    fi

    # resolve environment variables in ldif file    
    cp ${LDAP_LDIFF} "${LDAP_LDIFF}.tmp"
    env | sed 's/[\%]/\\&/g;s/\([^=]*\)=\(.*\)/s%${\1}%\2%/' > ${TMP_ENVS}
    cat "${LDAP_LDIFF}.tmp" | sed -f ${TMP_ENVS} > ${LDAP_LDIFF}
    rm ${TMP_ENVS}
    rm "${LDAP_LDIFF}.tmp"
    echo -e "Start polling for LDAP autoconfiguration [HOSTNAME: ${HOSTNAME}, LDAP_USER_DN ${LDAP_USER_DN}, LDAP_BASE_DN: ${LDAP_BASE_DN}, LDAP_LDIFF: ${LDAP_LDIFF}]"
    nohup /usr/local/bin/load_ldif.sh -h ${HOSTNAME} -u ${LDAP_USER_DN} -p ${LDAP_PASSWORD} -b ${LDAP_BASE_DN} -f ${LDAP_LDIFF} &
done

