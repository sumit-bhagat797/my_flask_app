#!/bin/bash

echo "Content-type: text/html"
echo ""

# Read POST data from stdin
read -r QUERY_STRING

# Parse the query string into variables
declare -A form_data
IFS='&' read -r -a pairs <<< "$QUERY_STRING"
for pair in "${pairs[@]}"; do
    IFS='=' read -r key value <<< "$pair"
    form_data["$key"]=$(echo "$value" | sed 's/%20/ /g' | sed 's/[^a-zA-Z0-9.:_/-]//g')  # Sanitize input
done

# Extract values
num_servers="${form_data[numServers]}"
frontend_port="${form_data[frontend_port]}"
load_balancing="${form_data[load_balancing]}"  # Extract the selected load balancing algorithm
username="${form_data[username]}"
password="${form_data[password]}"

# Paths and variables
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
BACKUP_CFG="/etc/haproxy/haproxy.cfg.bak"

# Backup current configuration
cp $HAPROXY_CFG $BACKUP_CFG

# Clear existing configuration file
> $HAPROXY_CFG

# Start constructing the HAProxy configuration
{
    echo "#---------------------------------------------------------------------"
    echo "# Example configuration for a possible web application.  See the"
    echo "# full configuration options online."
    echo "#"
    echo "#   https://www.haproxy.org/download/1.8/doc/configuration.txt"
    echo "#---------------------------------------------------------------------"
    echo ""
    echo "#---------------------------------------------------------------------"
    echo "# Global settings"
    echo "#---------------------------------------------------------------------"
    echo "global"
    echo "    log         127.0.0.1 local2"
    echo "    chroot      /var/lib/haproxy"
    echo "    pidfile     /var/run/haproxy.pid"
    echo "    maxconn     1000"  # Updated maxconn value
    echo "    user        haproxy"
    echo "    group       haproxy"
    echo "    daemon"
    echo ""
    echo "    # turn on stats unix socket"
    echo "    stats socket /var/lib/haproxy/stats"
    echo ""
    echo "    # utilize system-wide crypto-policies"
    echo "    ssl-default-bind-ciphers PROFILE=SYSTEM"
    echo "    ssl-default-server-ciphers PROFILE=SYSTEM"
    echo ""
    echo "#---------------------------------------------------------------------"
    echo "# common defaults that all the 'listen' and 'backend' sections will"
    echo "# use if not designated in their block"
    echo "#---------------------------------------------------------------------"
    echo "defaults"
    echo "    mode                    http"
    echo "    log                     global"
    echo "    option                  httplog"
    echo "    option                  dontlognull"
    echo "    option http-server-close"
    echo "    option forwardfor       except 127.0.0.0/8"
    echo "    option                  redispatch"
    echo "    retries                 3"
    echo "    timeout http-request    10s"
    echo "    timeout queue           1m"
    echo "    timeout connect         10s"
    echo "    timeout client          1m"
    echo "    timeout server          1m"
    echo "    timeout http-keep-alive 10s"
    echo "    timeout check           10s"
    echo "    maxconn                 1000"  # Updated maxconn value
    echo ""
    echo "#---------------------------------------------------------------------"
    echo "# main frontend which proxys to the backends"
    echo "#---------------------------------------------------------------------"
    echo "frontend main"
    echo "    bind *:$frontend_port"
    echo "    acl url_static       path_beg       -i /static /images /javascript /stylesheets"
    echo "    acl url_static       path_end       -i .jpg .gif .png .css .js"
    echo ""
    echo "    use_backend static          if url_static"
    echo "    default_backend             app"
    echo ""
    echo "#---------------------------------------------------------------------"
    echo "# static backend for serving up images, stylesheets and such"
    echo "#---------------------------------------------------------------------"
    echo "backend static"
    echo "    balance     roundrobin"
    echo "    server      static 127.0.0.1:4331 check"
    echo ""
    echo "#---------------------------------------------------------------------"
    echo "# $load_balancing balancing between the various backends"
    echo "#---------------------------------------------------------------------"
    echo "backend app"
    echo "    balance     $load_balancing"  # Use the selected load balancing algorithm

    # Append backend servers to configuration
    for i in $(seq 1 $num_servers); do
        ip="${form_data[backend${i}_ip]}"
        port="${form_data[backend${i}_port]}"
        echo "    server app${i} ${ip}:${port} check"
    done

    # HAProxy monitoring configuration
    echo ""
    echo "#---------------------------------------------------------------------"
    echo "# Monitoring interface"
    echo "#---------------------------------------------------------------------"
    echo "listen haproxy3-monitoring"
    echo "    bind *:8080"
    echo "    mode http"
    echo "    option forwardfor"
    echo "    option httpclose"
    echo "    stats enable"
    echo "    stats show-legends"
    echo "    stats refresh 5s"
    echo "    stats uri /stats"
    echo "    stats realm Haproxy\ Statistics"
    echo "    stats auth $username:$password"
    echo "    stats admin if TRUE"
} >> $HAPROXY_CFG

# Output result (Removed)
# echo "<html><body>"
# echo "<h2>HAProxy Configuration Updated</h2>"
# echo "<p>Frontend Port: $frontend_port</p>"
# echo "<p>Load Balancing Algorithm: $load_balancing</p>"
# echo "<p>Username: $username</p>"
# echo "<p>Password: [hidden]</p>"
# echo "<p>Backend Servers:</p>"
# for i in $(seq 1 $num_servers); do
#     ip="${form_data[backend${i}_ip]}"
#     port="${form_data[backend${i}_port]}"
#     echo "<p>App${i}: ${ip}:${port}</p>"
# done
# echo "</body></html>"

