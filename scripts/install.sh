#!/usr/bin/env bash
################################################################################
# Title:  SIPDomainProxy
# Author: Robert J. Ebel
################################################################################

# Run this script as root.

# This script assumes a clean slate and will do what it needs to install
# kamailio, rtpengine and postgresql -- There are no options at this time.

# It is also assumed that there is only a single ip address on this sytem
# and that this system is behind a NAT router. It is assumed that PBX's are
# on this same LAN.


DBDRIVER='postgres'
DBHOST='127.0.0.1'
DBUSER=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c20)
DBPASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c20)
DBNAME=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c20)
KAMAILIO_USER=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c20)
RTE_USER=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c20)
PUBADDR=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{ print $2}')
# Another option $(dig -4 +short myip.opendns.com @resolver1.opendns.com)
PRIVADDR=$(ip route list match 0 | cut -f 3 -d ' ')
PRIVSUBNET=$(ip route list match $PRIVADDR | grep $PRIVADDR | cut -f 1 -d ' ' | cut -f 1 -d '/')
PRIVMASK=$(ip route list match $PRIVADDR | grep $PRIVADDR | cut -f 1 -d ' ' | cut -f 1 -d '/')
SIPPORT='5060'
SIPTLSPORT='5061'
RTPE_SOCKET='127.0.0.1:2223'


# Create user accounts
if ! grep -qE "^/usr/sbin/nologin" /etc/shells
then
  bash -c 'echo '/usr/sbin/nologin' >> /etc/shells'
fi
useradd -s /usr/sbin/nologin $KAMAILIO_USER
useradd -s /usr/sbin/nologin $RTE_USER

# Install the intially required packages
apt-get -y install build-essential bison flex git wget

# Add the official PostgreSQL Apt Repository
echo 'deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main' \
  > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
  sudo apt-key add -
sudo apt-get update

# Install Postgres 10
apt-get -y install postgresql-10 postgresql-server-dev-10

# Setup PostgreSQL
PSQLDIR='/etc/postgresql/10/main'
sed -i -e "s/127.0.0.1\/32  *md5/127.0.0.1\/32     trust/" \
 $PSQLDIR/pg_hba.conf
sed -i -e "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/max_connections = 100/max_connections = 30/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/shared_buffers = 128MB/shared_buffers = 512MB/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/#max_prepared_transactions = 0/max_prepared_transactions = 24/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/#work_mem = 4MB/work_mem = 64MB/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 256MB/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/#max_stack_depth = 2MB/max_stack_depth = 4MB/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/#synchronous_commit = on/synchronous_commit = off/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/#effective_cache_size = 4GB/effective_cache_size = 2GB/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/#log_lock_waits = off/log_lock_waits = on/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/#log_statement = 'none'/log_statement = 'all'/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/log_timezone = 'UTC'/log_timezone = 'US\/Pacific'/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/#autovacuum = on/autovacuum = on/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/timezone = 'UTC'/timezone = 'US\/Pacific'/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/lc_messages = 'C'/lc_messages = 'en_US.UTF-8'/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/lc_monetary = 'C'/lc_monetary = 'en_US.UTF-8'/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/lc_numeric = 'C'/lc_numeric = 'en_US.UTF-8'/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/lc_time = 'C'/lc_time = 'en_US.UTF-8'/" \
 $PSQLDIR/postgresql.conf
sed -i -e "s/#max_locks_per_transaction = 64/max_locks_per_transaction = 64/" \
 $PSQLDIR/postgresql.conf
systemctl restart postgresql
