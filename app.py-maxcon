from flask import Flask, request, render_template, redirect, url_for
import os
import subprocess

app = Flask(__name__)

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        num_servers = request.form.get('numServers', '0')

        # Handle frontend port selection
        frontend_port = request.form.get('frontend_port', '')
        if frontend_port == 'custom':
            frontend_port = request.form.get('custom_frontend_port', '')

        # Handle backend port selection
        backend_ports = []
        for i in range(1, int(num_servers) + 1):
            port_select = request.form.get(f'app{i}_port_select', '')
            if port_select == 'custom':
                port = request.form.get(f'custom_app{i}_port', '')
            else:
                port = port_select
            backend_ports.append((request.form.get(f'app{i}_ip'), port))

        # Get maxconn value
        maxconn_value = request.form.get('maxconn', '1000')

        load_balancing = request.form.get('load_balancing', 'roundrobin')
        username = request.form.get('username', '')
        password = request.form.get('password', '')

        ssl_pem_path = ''
        if 'ssl_pem' in request.files:
            ssl_file = request.files['ssl_pem']
            if ssl_file.filename.endswith('.pem'):
                ssl_pem_path = os.path.join('/etc/haproxy/', ssl_file.filename)
                ssl_file.save(ssl_pem_path)

        haproxy_cfg_path = '/etc/haproxy/haproxy.cfg'

        # Ensure load_balancing value is valid
        valid_algorithms = ['roundrobin', 'leastconn', 'first']
        if load_balancing not in valid_algorithms:
            load_balancing = 'roundrobin'

        # Generate HAProxy configuration
        with open(haproxy_cfg_path, 'w') as f:
            f.write(f"""
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log 127.0.0.1 local0
    chroot /var/lib/haproxy
    stats socket /var/run/haproxy.sock mode 600
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

#---------------------------------------------------------------------
# Default settings
#---------------------------------------------------------------------
defaults
    log global
    option httplog
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms
    maxconn {maxconn_value}

#---------------------------------------------------------------------
# HAProxy Monitoring Config
#---------------------------------------------------------------------
listen stats
    bind *:8080
    mode http
    option forwardfor
    option httpclose
    stats enable
    stats show-legends
    stats hide-version
    stats refresh 5s
    stats uri /stats
    stats realm Haproxy\\ Statistics
    stats auth {username}:{password}

#---------------------------------------------------------------------
# Frontend for HTTP
#---------------------------------------------------------------------
frontend main_http
    log 127.0.0.1 local6
    option httplog
    bind *:{frontend_port}
    mode http
    option forwardfor
    default_backend app-http
    maxconn {maxconn_value}

#---------------------------------------------------------------------
# Frontend for HTTPS
#---------------------------------------------------------------------
frontend main_https
    log 127.0.0.1 local6
""")
            if ssl_pem_path:
                f.write(f"       bind *:443 ssl crt {ssl_pem_path}\n")
            else:
                f.write("       bind *:443\n")

            f.write(f"""
#---------------------------------------------------------------------
# Backend for HTTP
#---------------------------------------------------------------------
backend app-http
    mode http
    balance {load_balancing}
    stick-table type ip size 200k expire 20m
    stick on src
    default-server inter 1s
    maxconn {maxconn_value}
""")
            for i in range(1, int(num_servers) + 1):
                app_ip = request.form.get(f'app{i}_ip')
                if app_ip:
                    f.write(f"       server app{i} {app_ip}:80 check\n")

            f.write(f"""
#---------------------------------------------------------------------
# Backend for HTTPS
#---------------------------------------------------------------------
backend app-https
    mode http
    balance {load_balancing}
    option forwardfor
    stick-table type ip size 200k expire 20m
    stick on src
    default-server inter 1s
    maxconn {maxconn_value}
""")
            for i, (app_ip, app_port) in enumerate(backend_ports, start=1):
                if app_ip and app_port:
                    f.write(f"       server app{i} {app_ip}:{app_port} check ssl verify none\n")

        # Restart the HAProxy service after the configuration is updated
        try:
            subprocess.run(['systemctl', 'restart', 'haproxy'], check=True)
            restart_status = "HAProxy service restarted successfully."
        except subprocess.CalledProcessError as e:
            restart_status = f"Failed to restart HAProxy: {e}"

        # Redirect to a success page with server IP and restart status
        server_ip = os.popen('hostname -I').read().strip()
        return render_template('success.html', server_ip=server_ip, restart_status=restart_status)

    return render_template('index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

