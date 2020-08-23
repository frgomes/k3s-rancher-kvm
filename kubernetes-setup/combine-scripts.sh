echo "export K3S_TOKEN=" | cat - /tmp/access_token_command | { tr -d '\n'; echo; } > /tmp/access_token_command_tmp
cat /tmp/access_token_command_tmp /tmp/k3s-worker-install.sh > /tmp/k3s-install.sh
chown vagrant:vagrant /tmp/k3s-install.sh
chmod +x /tmp/k3s-install.sh
