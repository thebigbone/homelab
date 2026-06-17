#############################################
# initialization for openbsd firewall boxes #
#############################################

from pyinfra.operations import pkg, git, server, bsdinit, files
from pyinfra import host
import os

sysctl_settings = [
    {"key": "net.inet.ip.forwarding", "value": 1, "name": "sysctl - enable IP forwarding"},
    {"key": "net.inet6.ip6.forwarding", "value": 1, "name": "sysctl - enable IPv6 forwarding"},
    {"key": "net.inet.esp.enable", "value": 0, "name": "sysctl - disable ESP"},
    {"key": "net.inet.ah.enable", "value": 0, "name": "sysctl - disable AH"},
    {"key": "net.inet.icmp.drop_redirect", "value": 1, "name": "sysctl - drop ICMP redirects"},
    {"key": "net.inet.ip.check_interface", "value": 1, "name": "sysctl - enable IP interface checking"},
]

enable_services = [
    {"name": "sshd"},
    {"name": "ntpd"},
    {"name": "syslogd"},
    {"name": "cron"},
    {"name": "resolvd"},
    {"name": "nginx"},
    {"name": "unbound"},
    {"name": "dnsdist"},
]

copy_files = [
    {"name": "copy pf.conf", "src": "/usr/local/src/infra/firewall/pf.conf", "dest": "/etc/"},
    {"name": "copy sshd_config", "src": "/usr/local/src/infra/misc/ssh/sshd_config", "dest": "/etc/ssh"},
    {"name": "copy nginx configs", "src": "/usr/local/src/infra/misc/etc/nginx/", "dest": "/etc/nginx/"},
    {"name": "copy unbound configs", "src": "/usr/local/src/infra/dns/unbound/", "dest": "/var/unbound/etc/"},
    {"name": "copy dnsdist config", "src": "/usr/local/src/infra/dns/dnsdist/", "dest": "/etc/dnsdist/"},
]

disable_services = [{'name': line.strip()} for line in open('./firewall/disable', 'r').readlines() if line.strip()]

for disable_service in disable_services:
    server.shell(
        name=f"disable init services - {disable_service['name']}",
        commands=[f"rcctl disable {disable_service['name']}"]
    )

    # too slow
    #bsdinit.service(
    #    name=f"disable init services - {disable_service['name']}",
    #    service=disable_service['name'],
    #    running=False,
    #    enabled=False,
    #)


server.shell(
    name="update the mirror",
    commands=["echo 'https://cdn.openbsd.org/pub/OpenBSD' > /etc/installurl"],
)

server.shell(
    name="update all packages",
    commands=["pkg_add -v -u"],
)

pkg.packages(
    name="install required packages",
    packages=["wget", "vim", "htop", "fastfetch", "unbound", "dnsdist", "git", "wireguard-tools", "nginx", "nginx-modsecurity", "sops"],
)

server.timezone(
    name="set the timezone",
    timezone="Asia/Singapore",
)

for setting in sysctl_settings:
    server.sysctl(
        name=setting["name"],
        key=setting["key"],
        value=setting["value"],
        persist=True,
    )

if host.data.get("firewall-01"):
    server.hostname(
        name=f"set the hostname to {host.name}",
        hostname="fw-01",
    )

if host.data.get("firewall-02"):
    server.hostname(
        name=f'set the hostname for {host.name}',
        hostname="fw-02",
    )

if os.path.isdir("/usr/local/src/infra"):
    server.shell(
        name="repo exists. git pull",
        commands=["cd /usr/local/src/infra; git pull"],
    )

if not os.path.isdir("/usr/local/src/infra"):
    git.repo(
        name="clone repo for configs",
        src="https://git.ext4.xyz/frost/infra.git",
        dest="/usr/local/src/infra",
    )

for copy_file in copy_files:
    files.copy(
        name=copy_file["name"],
        src=copy_file["src"],
        dest=copy_file["dest"],
        overwrite=True,
    )

files.directory(
    name="ensure /etc/letsencrypt/live/ext4.xyz exists",
    path="/etc/letsencrypt/live/ext4.xyz",
)

files.directory(
    name="ensure /var/log/nginx exists",
    path="/var/log/nginx",
)

files.directory(
    name="ensure /etc/unbound exists",
    path="/etc/unbound",
)

files.directory(
    name="ensure /etc/nginx/modsec exists",
    path="/etc/nginx/modsec",
)

server.shell(
    name="configure modsecurity",
    commands=["git clone https://github.com/coreruleset/coreruleset /usr/local/modsecurity-crs; mv /usr/local/modsecurity-crs/crs-setup.conf.example /usr/local/modsecurity-crs/crs-setup.conf; mv /usr/local/modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example /usr/local/modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf; wget https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/refs/heads/v3/master/unicode.mapping -O /etc/nginx/modsec/unicode.mapping; wget https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/refs/heads/v3/master/modsecurity.conf-recommended -O /etc/nginx/modsec/modsecurity.conf; sed -i 's/DetectionOnly/On/g' /etc/nginx/modsec/modsecurity.conf"],
)

# rsync the private key to ~/.config/sops/age/keys.txt
server.shell(
    name="decrypt wg config",
    commands=["sops --decrypt /usr/local/src/infra/misc/wireguard/hostname.wg0.enc > /etc/hostname.wg0"],
)

server.shell(
    name="decrypt cert",
    commands=["sops --decrypt /usr/local/src/infra/misc/cert/fullchain.pem.enc > /etc/letsencrypt/live/ext4.xyz/fullchain.pem; sops --decrypt /usr/local/src/infra/misc/cert/privchain.pem.enc > /etc/letsencrypt/live/ext4.xyz/privkey.pem"],
)

for enable_service in enable_services:
    server.shell(
        name=f"enable init services - {enable_service['name']}",
        commands=[f"rcctl disable {enable_service['name']}"]
    )
