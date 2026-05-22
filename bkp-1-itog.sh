# 1. Сеть
ip -br a

# 2. Пинг GW-01
ping -c 2 10.0.10.1

# 3. Пинг SRV-DC-01
ping -c 2 10.0.10.10

# 4. Статус SSH
#systemctl status sshd

# 5. Статус Chrony
#systemctl status chronyd
