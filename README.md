# SIPDomainProxy
SIPDomainProxy facilitates communications between SIP endpoints on the public
Internet and any number of SIP servers on a private network. SIP requests are
routed to a SIP server based on the domain name used to contact the proxy.

This application can *passthrough* registration requests to a PBX or it can
handle the *registration* for a domain.

If this application is handling the registration, a SIP endpoint may be
authenticated using *digest* authentication or by a *trusted address*.
Digest and trusted addresses may be used simultaneously with differing priority
levels. If a digest and trusted address have the same priority, digest
authentication will be attempted first.

# Installation
The install script assumes it has full control over the system you are
installing this application on and will go about updating and installing all
of the packages necessary to get this application operational. To recap what it
will do:

* Install packages necessary to build packages from source
* Install a number of perl packages
* Install a number of dependencies for kamailio and rtpengine
* Install and configure PostgreSQL
* Install kamailio and rtpengine
* Add a chain to iptables for rtpengine
* Install a number of systemd unit scripts

It is expected that this will be installed on an Ubuntu 18.04 box. At this time
no other systems have been tested.

A clean installation with basic networking is recommended.

To install, simply run the install script in the scripts directory.

```bash
cd SIPDomainProxy/scripts
./install.sh
```
