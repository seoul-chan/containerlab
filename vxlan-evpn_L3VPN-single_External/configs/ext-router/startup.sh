#!/bin/sh

# 1. IP 포워딩 활성화 (라우터로 동작하기 위해 필수)
sysctl -w net.ipv4.ip_forward=1

# 2. Border Leaf(leaf1)와 연결되는 내부 인터페이스(eth1) 설정
# (leaf1:eth5 192.168.100.1/24, ext-router:eth1 192.168.100.2/24)
ip addr add 192.168.100.2/24 dev eth1

# 3. 내부 Overlay 대역으로 돌아가는 경로 추가
# (Host 대역이 172.16.x.x라고 가정)
# Border Leaf가 모든 Overlay 대역을 알고 있으므로, 넥스트홉으로 지정
ip route add 172.16.0.0/16 via 192.168.100.1

# 4. NAT 설정 (IP Masquerade)
# eth0 (컨테이너의 기본 인터페이스)를 외부 인터넷망으로 간주
# 172.16.0.0/16 대역에서 오는 모든 트래픽을 eth0의 IP로 NAT 처리
iptables -t nat -A POSTROUTING -s 172.16.0.0/16 -o eth0 -j MASQUERADE