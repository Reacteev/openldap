FROM debian:stretch

MAINTAINER Reacteev, <reacteev>

# Replicate all default environment variables from the base image and customize the needed one's. 
# This is to be able to use a custom entrypoint and perform all needed settings

ENV INITIAL_ADMIN_USER admin.user
ENV INITIAL_ADMIN_PASSWORD=""
ENV NEXUS_PASSWORD=""
ENV GITLAB_PASSWORD=""
ENV JENKINS_PASSWORD=""
ENV SLAPD_PASSWORD=""
ENV SLAPD_DOMAIN ldap.example.com
ENV SLAPD_FULL_DOMAIN "dc=ldap,dc=example,dc=com"
# ENV SLAPD_ORGANIZATION
ENV SLAPD_ADDITIONAL_SCHEMAS "dyngroup,ppolicy"
ENV SLAPD_ADDITIONAL_MODULES "memberof,pw-pbkdf2,ppolicy"
ENV SLAPD_LDIF_BASE="/var/tmp/ldifs"
ENV SLAPD_LOAD_LDIFS=""
# ENV SLAPD_FORCE_RECONFIGURE
ENV OPENLDAP_VERSION 2.4.47

# End environment variable definition

COPY resources/stretch-backports.list /etc/apt/sources.list.d/stretch-backports.list

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -t stretch-backports slapd=${OPENLDAP_VERSION}* slapd-contrib=${OPENLDAP_VERSION}* ldap-utils

RUN mv /etc/ldap /etc/ldap.dist

EXPOSE 389

VOLUME ["/etc/ldap", "/var/lib/ldap"]

# Copy in configuration files

COPY resources/modules/ /etc/ldap.dist/modules

COPY resources/configuration/check_password.conf /etc/ldap.dist/check_password.conf

COPY resources/ldap_init.sh /usr/local/bin/
RUN chmod u+x /usr/local/bin/ldap_init.sh

COPY resources/load_ldif.sh /usr/local/bin/
RUN chmod u+x /usr/local/bin/load_ldif.sh

COPY resources/ldifs /var/tmp/ldifs

COPY resources/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod u+x /usr/local/bin/entrypoint.sh

# Install ldap utility commands
RUN cp -a /etc/ldap.dist/* /etc/ldap && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y wget gcc make file libdb-dev libltdl-dev

# Get openldap source to compile check password
RUN wget -O /root/openldap-${OPENLDAP_VERSION}.tgz https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-${OPENLDAP_VERSION}.tgz && \
	cd /root && \
	tar -zxvf openldap-${OPENLDAP_VERSION}.tgz &&  \
	cd openldap-${OPENLDAP_VERSION} && ./configure --prefix=/usr && \
	make depend

RUN wget -O /root/cracklib-2.9.7.tar.gz https://github.com/cracklib/cracklib/releases/download/v2.9.7/cracklib-2.9.7.tar.gz && \
	cd /root && gunzip cracklib-2.9.7.tar.gz && tar -xvf cracklib-2.9.7.tar && \
	cd cracklib-2.9.7 && ./configure --prefix=/usr --disable-static  --with-default-dict=/lib/cracklib/pw_dict && \
	make && make install

RUN wget -O /root/cracklib-words-2.9.7.gz https://github.com/cracklib/cracklib/releases/download/v2.9.7/cracklib-words-2.9.7.gz && \
        install -v -m644 -D /root/cracklib-words-2.9.7.gz /usr/share/dict/cracklib-words.gz && \
	gunzip -v /usr/share/dict/cracklib-words.gz && \
	ln -v -sf cracklib-words /usr/share/dict/words && install -v -m755 -d /lib/cracklib &&\
        create-cracklib-dict /usr/share/dict/cracklib-words

RUN wget -O /root/openldap-ppolicy-check-password-1.1.tar.gz https://github.com/ltb-project/openldap-ppolicy-check-password/archive/v1.1.tar.gz && \
	cd /root && gunzip openldap-ppolicy-check-password-1.1.tar.gz && tar -xvf openldap-ppolicy-check-password-1.1.tar && \
	cd openldap-ppolicy-check-password-1.1 && \
	make install  CONFIG="/etc/ldap/check_password.conf" LDAP_INC="-I/root/openldap-${OPENLDAP_VERSION}/include/ -I/root/openldap-${OPENLDAP_VERSION}/servers/slapd" \
	CRACKLIB="/lib/cracklib/" CRACKLIB_LIB="/usr/lib/libcrack.so.2" LIBDIR="/usr/lib/ldap/"

# Cleanup
RUN DEBIAN_FRONTEND=noninteractive apt-get remove -y wget gcc make file libdb-dev libltdl-dev && \
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/*

# Override entry point
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["slapd", "-d", "32768", "-u", "openldap", "-g", "openldap", "-h", "ldap:/// ldapi:///"]
