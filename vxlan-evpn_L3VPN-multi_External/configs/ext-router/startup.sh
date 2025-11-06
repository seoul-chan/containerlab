#!/bin/sh

# 1. IP 포워딩 활성화
sysctl -w net.ipv4.ip_forward=1

# 2. Border Leaf(borderleaf1)와 연결되는 인터페이스 설정
# VRF A용 링크 (192.168.100.x)
ip addr add 192.168.100.2/24 dev eth1
# VRF B용 링크 (192.168.200.x)
ip addr add 192.168.200.2/24 dev eth2

# 3. NAT 설정 (IP Masquerade)
# 172.16.0.0/16 대역에서 오는 모든 트래픽을 eth0의 IP로 NAT 처리
# (-i 플래그를 제거하고 소스 IP 대역(-s)으로만 필터링)
iptables -t nat -A POSTROUTING -s 172.16.0.0/16 -o eth0 -j MASQUERADE