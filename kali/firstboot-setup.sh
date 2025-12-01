#!/usr/bin/env bash

HOST=attacker
IFACE=$(nmcli -t -f DEVICE,TYPE d | awk -F: '$2=="ethernet"{print $1; exit}')

echo "$HOST" > /etc/hostname
sed -i '/^127\.0\.1\.1/d' /etc/hosts
printf '127.0.1.1 %s\n' "$HOST" >> /etc/hosts
hostnamectl set-hostname "$HOST"
timedatectl set-timezone Europe/Riga

nmcli con down id "Wired connection 1"
nmcli con delete id "Wired connection 1"
nmcli con add type ethernet ifname "$IFACE" con-name labnet ipv4.method manual ipv4.addresses 10.99.20.30/24 ipv4.gateway 10.99.20.254 ipv4.dns "8.8.8.8,8.8.4.4" ipv6.method ignore
nmcli con up labnet

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade

systemctl restart systemd-timesyncd
