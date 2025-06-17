#!/bin/bash

# ----------------------------
# Topologie :
# enp0s3 → 192.168.1.1 (vers client)
# enp0s8 → DHCP (vers Internet) ✅
# enp0s9 → 172.16.1.1 (vers serveur Web/SSH/FTP)
# ----------------------------
# SERVER WEB -------
#INSTALLER SSH et serveur web avec deuxième carte accès par pont avant de lancer le script
# mettre un dns 8.8.8.8 resolv.conf
#----------
# CLIENT -------
# mettre un dns 8.8.8.8 resolv.conf
#----------

# Export PATH pour accès à iptables
#export PATH=$PATH:/usr/sbin
#Véfication critère examen
# 1 : iptables -L (sur firewall) chain INPUT OUTPUT...
# 2 : ping 8.8.8.8 sur client doit être ok
# 3 : Client accès serveur web  via http://172.16.1.2
# 4 : iptables -L -v -n trouver ctstate RELATED,ESTABLISHED dans chaque partie
# 5 : ping 127.0.0.1 sur le firewall
# 6 : iptables -L INPUT et iptables -L FORWARD 
# 7 : Tester de ce connecter en ssh depuis client au server web ssh -p 61337 user@172.16.1.1
# 8 : ping 172.16.1.1 depuis firewall fonctionne ping 192.168.1.1 depuis client fonctionne pas
# 9 : iptables -L HTTPS_LOG -v -n : sur firewall on doit voir pkts > 0

#Début du script
# -------- FLUSH -------- #
iptables -F INPUT
iptables -F OUTPUT
iptables -F FORWARD
iptables -t nat -F PREROUTING
iptables -t nat -F POSTROUTING
iptables -X

# Politique par défaut
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# -------- INPUT -------- #
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -s 172.16.1.2 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -j REJECT

# -------- OUTPUT -------- #
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-request -d 172.16.1.2 -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -j REJECT

# -------- FORWARD -------- #

# Autoriser connexions établies
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# NAT Masquerading vers Internet (interface enp0s8)
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o enp0s8 -j MASQUERADE

# Le client peut accéder à Internet (enp0s3 vers enp0s8)
iptables -A FORWARD -s 192.168.1.0/24 -i enp0s3 -o enp0s8 -j ACCEPT

# Le client peut accéder au serveur Web (port 80) via enp0s9
iptables -A FORWARD -p tcp --dport 80 -s 192.168.1.0/24 -i enp0s3 -o enp0s9 -j ACCEPT

# Redirection SSH port 61337 → 22 sur serveur (172.16.1.2)
iptables -t nat -A PREROUTING -i enp0s9 -p tcp --dport 61337 -j DNAT --to-destination 172.16.1.2:22
iptables -A FORWARD -p tcp -d 172.16.1.2 --dport 22 -j ACCEPT

# Limiter le ping au pare-feu uniquement depuis le serveur
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# Compteur pour HTTPS depuis client
iptables -N HTTPS_LOG
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 443 -j HTTPS_LOG
iptables -A HTTPS_LOG -j ACCEPT
