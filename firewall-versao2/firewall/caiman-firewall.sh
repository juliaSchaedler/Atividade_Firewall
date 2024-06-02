#!/bin/bash
ip route del default 
ip route add default via 192.168.2.2
ip route add 192.168.1.0/24 via eth0

echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

#Políticas padrões
iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT DROP

#Permitir conexxões de saída da rede interna (192.168.3.0/24) para a internet e DMZ nas portas 80 e 443
iptables -A FORWARD -s 192.168.3.0/24 -d 0.0.0.0/0 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 192.168.3.0/24 -d 0.0.0.0/0 -p tcp --dport 443 -j ACCEPT

#Permitir conexões de saída da rede interna (192.168.3.0/24) para a Internet nas portas email
iptables -A FORWARD -s 192.168.3.0/24 -d 0.0.0.0/0 -p tcp --dport 465 -j ACCEPT #SMTP
iptables -A FORWARD -s 192.168.3.0/24 -d 0.0.0.0/0 -p tcp --dport 587 -j ACCEPT #SMTP
iptables -A FORWARD -s 192.168.3.0/24 -d 0.0.0.0/0 -p tcp --dport 995 -j ACCEPT #POP3
iptables -A FORWARD -s 192.168.3.0/24 -d 0.0.0.0/0 -p tcp --dport 143 -j ACCEPT #IMAP
iptables -A FORWARD -s 192.168.3.0/24 -d 0.0.0.0/0 -p tcp --dport 993 -j ACCEPT #IMAP

#Permitir acesso da rede interna (192.168.3.0/24) ao servidor de aplicações (192.168.2.8)
iptables -A FORWARD -s 192.168.3.0/24 -d 192.168.2.8 -p tcp -j ACCEPT

#Bloquear acesso da rede interna (192.168.3.0/24) as portas 80 e 443
iptables -A FORWARD -i eth0 -p tcp --dport 80 -j LOG --log-prefix "IPTables-HTTP-Reject: " --log-level 4
iptables -A FORWARD -i eth0 -p tcp --dport 443 -j LOG --log-prefix "IPTables-HTTPS-Reject: " --log-level 4

iptables -A FORWARD -i eth0 -p tcp --dport 80 -j REJECT
iptables -A FORWARD -i eth0 -p tcp --dport 443 -j REJECT

#Bloquear todo acesso à porta 5432 no servidor de banco de dados
iptables -A FORWARD -i eth1 -d 192.168.2.7 -p tcp --dport 5432 -j LOG --log-prefix "IPTables-DB-Dropped: " --log-level 4
iptables -A FORWARD -i eth1 -d 192.168.2.7 -p udp --dport 5432 -j LOG --log-prefix "IPTables-DB-Dropped: " --log-level 4

iptables -A FORWARD -i eth1 -d 192.168.2.7 -p tcp --dport 5432 -j DROP
iptables -A FORWARD -i eth1 -d 192.168.2.7 -p udp --dport 5432 -j DROP

#Bloquear acesso direto da Internet para a estação de trabalho (e permitir respostas para conexões establecidas e/ou relacionados)
iptables -A FORWARD -s 192.168.1.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -A FORWARD -s 192.168.1.0/24 -j LOG --log-prefix "IPTables-DirectAcessFromInternet-Dropped: " --log-level 4
iptables -A FORWARD -s 192.168.1.0/24 -j DROP

#Impedir que a rede interna acesse portas aleatórias da internet
iptables -A FORWARD -d 192.168.1.0/24 -j LOG --log-prefix "IPTables-TryToAcessDeniedPortsOfInternet-Dropped: " --log-level 4
iptables -A FORWARD -d 192.168.1.0/24 -j DROP

#Permitir todo o tráfego entre a rede interna e DMZ
#Rede internar requisita e servidores só respondem
iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eht1 -o eht0 -j ACCEPT