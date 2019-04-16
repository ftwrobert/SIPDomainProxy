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


DB_DRIVER='postgres'
DB_HOST='127.0.0.1'
DB_USER=kamailio
DB_PASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c20)
DB_NAME=sipdomainproxy
DBPORT=5432
KAMAILIO_USER=kamailio
PUBADDR=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{ print $2}')
# Another option $(dig -4 +short myip.opendns.com @resolver1.opendns.com)
DEFGW=$(ip route list match 0 | cut -f 3 -d ' ')
ROUTE=$(ip route list match $DEFGW | grep -v $DEFGW)
PRIVADDR=$(echo "$ROUTE" | grep -oE "src .*" | cut -f 2 -d ' ')
PRIVSUBNET=$(echo "$ROUTE" | cut -f 1 -d '/')
PRIVMASK=$(echo "$ROUTE" | cut -f 2 -d '/' | cut -f 1 -d ' ')
SIPPORT='5060'
SIPTLSPORT='5061'
RTPE_MIN_PORT='52000'
RTPE_MAX_PORT='54024'
RTPE_SOCKET='127.0.0.1:2223'
                  # Assuming we're installing on a LXD host
                  # The xt_RTPENGINE kernel module should already be loaded.
RTPE_KERNEL_MOD=0 # Set to 1 if installing in a VM or a dedicated host.
RTPE_FWD_TABLE=0        # https://github.com/sipwise/rtpengine#the-kernel-module
DSTKAMDIR="/etc/kamailio"

# Determine the working directory of SIPDomainProxy
SRCDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd ../ && pwd )
SRCKAMDIR="$SRCDIR/kamailio/conf"

# Create user accounts
if ! grep -qE "^/usr/sbin/nologin" /etc/shells
then
  bash -c 'echo '/usr/sbin/nologin' >> /etc/shells'
fi
useradd -s /usr/sbin/nologin $KAMAILIO_USER

apt-get -y update
# Install the intially required packages
apt-get -y install build-essential bison flex git wget
# RTPEngine Prerequisites
apt-get -y install dpkg-dev debhelper default-libmysqlclient-dev \
                   libmysqlclient-dev gperf iptables-dev libavcodec-dev \
                   libavfilter-dev libavformat-dev libavutil-dev \
                   libbencode-perl libcrypt-openssl-rsa-perl \
                   libcrypt-rijndael-perl libcurl4-openssl-dev \
                   libdigest-crc-perl libdigest-hmac-perl libevent-dev \
                   libglib2.0-dev libhiredis-dev libio-multiplex-perl \
                   libio-socket-inet6-perl libiptc-dev libjson-glib-dev \
                   libnet-interface-perl libpcap0.8-dev libpcre3-dev \
                   libsocket6-perl libssl-dev libswresample-dev libsystemd-dev \
                   libxmlrpc-core-c3-dev markdown zlib1g-dev

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

# Set up DB User and DB
cat > /tmp/sql_user <<SQL_COMMANDS
CREATE ROLE $DB_USER WITH PASSWORD '$DB_PASS' LOGIN;
CREATE DATABASE $DB_NAME WITH OWNER $DB_USER;
SQL_COMMANDS
su - -c 'psql -f /tmp/sql_user' postgres

# Download Kamailio
cd /usr/src
git clone https://github.com/kamailio/kamailio.git kamailio
cd kamailio
git checkout -b 5.2 origin/5.2
# and Install
make FLAVOUR=kamailio include_modules="db_postgres" cfg
make all
make install

# Kamailio Tables for postgres
psql -h $DB_HOST -U $DB_USER $DB_NAME \
-f /usr/src/kamailio/utils/kamctl/postgres/standard-create.sql
psql -h $DB_HOST -U $DB_USER $DB_NAME \
-f /usr/src/kamailio/utils/kamctl/postgres/permissions-create.sql
psql -h $DB_HOST -U $DB_USER $DB_NAME \
-f /usr/src/kamailio/utils/kamctl/postgres/rtpengine-create.sql
psql -h $DB_HOST -U $DB_USER $DB_NAME \
-f /usr/src/kamailio/utils/kamctl/postgres/alias_db-create.sql
psql -h $DB_HOST -U $DB_USER $DB_NAME \
-f /usr/src/kamailio/utils/kamctl/postgres/auth_db-create.sql
psql -h $DB_HOST -U $DB_USER $DB_NAME \
-f /usr/src/kamailio/utils/kamctl/postgres/domain-create.sql
psql -h $DB_HOST -U $DB_USER $DB_NAME \
-f /usr/src/kamailio/utils/kamctl/postgres/usrloc-create.sql
psql -h $DB_HOST -U $DB_USER $DB_NAME \
-f /usr/src/kamailio/utils/kamctl/postgres/registrar-create.sql

#!FIXME! Add custom tables for Account, Billing Group, Auth method and DID tracking

# Download RTPEngine
mkdir -p /usr/src/rtpengine
cd /usr/src/rtpengine
git clone https://github.com/sipwise/rtpengine.git rtpengine
cd rtpengine
git checkout -b mr7.2.1 origin/mr7.2.1
# Do not compile g729 support
export DEB_BUILD_PROFILES="pkg.ngcp-rtpengine.nobcg729"
# Build Deb packages
dpkg-buildpackage
cd /usr/src/rtpengine
# Install rtpengine and the iptables module for rtpengine
if [ ! -f ngcp-rtpengine-daemon_7.2.1.4+0~mr7.2.1.4_amd64.deb ]; then
  echo "deb packages were not successfully compiled, unable to continue"
  exit 1
fi

dpkg -i ngcp-rtpengine-daemon_7.2.1.4+0~mr7.2.1.4_amd64.deb
dpkg -i ngcp-rtpengine-iptables_7.2.1.4+0~mr7.2.1.4_amd64.deb
if [  $RTPE_KERNEL_MOD -eq 1 ]; then
  apt-get -y install dkms
  dpkg -i ngcp-rtpengine-kernel-dkms_7.2.1.4+0~mr7.2.1.4_all.deb
  modprobe xt_RTPENGINE
  echo 'xt_RTPENGINE' >> /etc/modules
fi

# Configure iptables to work with rtpengine in kernel space
iptables -I INPUT -p udp --dport $RTPE_MIN_PORT:$RTPE_MAX_PORT -j RTPENGINE\
 --id $RTPE_FWD_TABLE

# Utilize RTPEngine's --iptables-chain option to automatically open RTP ports
#   when UA's are actually going to use them.
iptables -N RTPENGINE_ALLOWED
iptables -I INPUT -p udp --dport $RTPE_MIN_PORT:$RTPE_MAX_PORT \
-j RTPENGINE_ALLOWED
iptables-save > /etc/iptables.conf

# RTPEngine config file
cat > /etc/rtpengine.conf <<CONF_FILE
[rtpengine]
listen-ng=$RTPE_SOCKET
pidfile=/var/run/rtpengine.pid
table=$RTPE_FWD_TABLE
tos=184
port-min=$RTPE_MIN_PORT
port-max=$RTPE_MAX_PORT
no-fallback=false
iptables-chain=RTPENGINE_ALLOWED
interface=$PRIVADDR
delete-delay=0
CONF_FILE

# Script to run BEFORE RTPEngine starts
cat > /usr/local/bin/before-rtpengine <<END_OF_SCRIPT
#!/usr/bin/env bash
iptables -F
iptables-restore /etc/iptables.conf
grep 'table=' /etc/rtpengine.conf | cut -d '=' -f 2 | for i in \$(cat); do\
 echo del \$i > /proc/rtpengine/control; \
done
exit 0
END_OF_SCRIPT
chmod +x /usr/local/bin/before-rtpengine

# RTPengine Startup Script
cat > /lib/systemd/system/rtpengine.service <<END_OF_UNIT_FILE
[Unit]
Description=NGCP RTP/media Proxy Daemon
After=network-online.target
After=remote-fs.target
Requires=network-online.target

[Service]
Type=forking
User=root
Group=root
PIDFile=/var/run/rtpengine.pid
ExecStartPre=-/usr/local/bin/before-rtpengine
ExecStart=/usr/sbin/rtpengine --config-file=/etc/rtpengine.conf\
 --config-section=rtpengine
ExecStopPost=-/bin/bash -c "grep 'table=' /etc/rtpengine.conf|cut -d '=' -f 2\
 | for i in \$(cat); do echo del \$i > /proc/rtpengine/control; done"
Restart=always

[Install]
WantedBy=multi-user.target
END_OF_UNIT_FILE

# Stop and disable the installed service
systemctl stop ngcp-rtpengine-daemon
systemctl disable ngcp-rtpengine-daemon
systemctl mask ngcp-rtpengine-daemon

# Enable and start rtpengine
systemctl enable rtpengine
echo "starting rtpengine"
systemctl start rtpengine
systemctl status rtpengine

# Kamailio Startup Script
cat > /lib/systemd/system/kamailio.service <<END_OF_UNIT_FILE
[Unit]
Description=Kamailio (OpenSER) - the Open Source SIP Server
After=network.target rtpengine.service

[Service]
Type=forking
Environment='OPTS=-m 512 -M 8 -u $KAMAILIO_USER -g $KAMAILIO_USER'
Environment='CFGFILE=/etc/kamailio/kamailio.cfg'
Environment='PIDFile=/var/run/kamailio.pid'
# PIDFile requires a full absolute path
PIDFile=/var/run/kamailio.pid
# ExecStart requires a full absolute path
ExecStart=/usr/local/sbin/kamailio -P \$PIDFile -f \$CFGFILE \$OPTS
Restart=always

[Install]
WantedBy=multi-user.target
END_OF_UNIT_FILE

# Link Kamailio source config to /etc/kamailio
ln -s "$SRCKAMDIR" "$DSTKAMDIR"
cd "$DSTKAMDIR"

cat > config.cfg <<EOF
#!KAMAILIO -- config for SIPDomainProxy
################################################################################
# Title:  SIPDomainProxy
# Author: Robert J. Ebel
################################################################################

# Database connectivity
#!subst "/DB_DRIVER/$DB_DRIVER/"
#!subst "/DB_HOST/$DB_HOST/"
#!subst "/DB_USER/$DB_USER/"
#!subst "/DB_PASS/$DB_PASS/"
#!subst "/DB_NAME/$DB_NAME/"

# IP Addresses
#!subst "/PUBADDR/$PUBADDR/"
#!subst "/PRIVADDR/$PRIVADDR/"
#!subst "/PRIVSUBNET/$PRIVSUBNET/"
#!subst "/PRIVMASK/$PRIVMASK/"

# RTP Engine paramaters
#!subst "/RTPE_SOCKET/$RTPE_SOCKET/"
EOF

# Enable and start Kamailio
systemctl enable kamailio
echo "starting kamailio"
chown -R $KAMAILIO_USER:$KAMAILIO_USER "$DSTKAMDIR"
systemctl start kamailio

cat <<DONE
Done, please confim that rtpengine has started correctly.
INFO: If you are running this in a LXD environment, please be aware:
        You need to reboot now to load the kernel module xt_RTPENGINE
SETTINGS:
  DB_DRIVER=$DB_DRIVER
  DB_HOST=$DB_HOST
  DB_USER=$DB_USER
  DB_PASS=$DB_PASS
  DB_NAME=$DB_NAME
  KAMAILIO_USER=$KAMAILIO_USER
  DBPORT=$DBPORT
  RTE_USER=$RTE_USER
  PUBADDR=$PUBADDR
  PRIVADDR=$PRIVADDR
  PRIVSUBNET=$PRIVSUBNET
  PRIVMASK=$PRIVMASK
  SIPPORT=$SIPPORT
  SIPTLSPORT=$SIPTLSPORT
  RTPE_MIN_PORT=$RTPE_MIN_PORT
  RTPE_MAX_PORT=$RTPE_MAX_PORT
  RTPE_SOCKET=$RTPE_SOCKET
  RTPE_KERNEL_MOD=$RTPE_KERNEL_MOD
  DSTKAMDIR=$DSTKAMDIR
  SRCDIR=$SRCDIR
  SRCKAMDIR=$SRCKAMDIR
DONE
