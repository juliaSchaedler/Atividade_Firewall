#!/bin/bash
ip route del default 
ip route add default via 192.168.2.2
ip route add 192.168.3.0/24 via eth0

echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

#Políticas padrões
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

#Permitir tráfego de loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

#Permitir conexões HTTP e HTTPS de entrada da DMZ para a rede externa
iptables -A FORWARD -i eth1 -o eth0 -d 192.168.2.6 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -d 192.168.2.6 -p tcp --dport 443 -j ACCEPT

#Permitir conexões HTTP e HTTPS de entrada da DMZ para a rede externa (para a rede interna acessar 80 e 443 da rede externa)
iptables -A FORWARD -d 192.168.1.0/24 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -d 192.168.1.0/24 -p tcp --dport 443 -j ACCEPT

#Permitir conexões DNS de entrada e saída (porta 53) através das interfaces específicas
iptables -A FORWARD -i eth1 -o eth0 -d 192.168.2.4 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -p udp --dport 53 -j ACCEPT

iptables -A FORWARD -i eth1 -o eth0 -d 192.168.2.4 -p tcp --dport 53 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -p tcp --dport 53 -j ACCEPT

#Permitir tráfego SMTP e IMAP de entrada para email (portas 465, 587, 995, 143, 993) através das interfaces específicas
iptables -A FORWARD -i eth1 -p tcp --dport 465 -j ACCEPT
iptables -A FORWARD -i eth1 -p tcp --dport 587 -j ACCEPT
iptables -A FORWARD -i eth1 -p tcp --dport 995 -j ACCEPT
iptables -A FORWARD -i eth1 -p tcp --dport 143 -j ACCEPT
iptables -A FORWARD -i eth1 -p tcp --dport 993 -j ACCEPT

#Bloquear todo o outro acesso à porta 5432 no servidor de banco de dados
iptables -A FORWARD -i eth1 -d 192.168.2.7 -p tcp --dport 5432 -j LOG --log-prefix "IPTables-DBAccess-Dropped: " --log-level 4
iptables -A FORWARD -i eth1 -d 192.168.2.7 -p tcp --dport 5432 -j DROP

#Bloquear o acesso ao servidor de aplicações (permitr no outro firewall)
iptables -A FORWARD -i eth1 -d 192.168.2.8 -p tcp -j LOG --log-prefix "IPTables-APPServerAccessFromInternet-Dropped: " --log-level 4
iptables -A FORWARD -i eth1 -d 192.168.2.8 -p tcp -j DROP

#A rede externa pode requisitar, mas os servidores só respondem
iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED, ESTABLISHED -j ACCEPT
#iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT

#Permitir respostas da rede externa e bloquear acesso direto da internet
iptables -A FORWARD -i eth1 -m state --state RELATED, ESTABLISHED -j ACCEPT

iptables -A FORWARD -i eth1 -j LOG --log-prefix "IPTables-DirectAccessFromInternet-Dropped: " --log-level 4
iptables -A FORWARD -i eth1 -j DROP