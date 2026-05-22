# 1. Сетевые интерфейсы
ip -br a

# 2. Уровень домена
samba-tool domain level show

# 3. Список пользователей домена
samba-tool user list

# 4. Статус Samba
systemctl status samba

# 5. Статус DHCP
systemctl status dhcpd

# 6. Проверка DNS
host -t A br67core.local 127.0.0.1

# 7. Проверка Kerberos (получение билета)
echo "P@ssw0rd!" | kinit administrator@BR67CORE.LOCAL && klist
