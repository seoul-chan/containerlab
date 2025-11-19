#!/bin/sh

# 1. IP 포워딩 활성화
sysctl -w net.ipv4.ip_forward=1

# 2. VLAN 모듈 로드 및 서브 인터페이스 생성 (eth1.100, eth1.200)
modprobe 8021q
ip link add link eth1 name eth1.100 type vlan id 100
ip link add link eth1 name eth1.200 type vlan id 200

# 3. IP 할당 및 인터페이스 활성화
ip addr add 192.168.100.2/24 dev eth1.100
ip addr add 192.168.200.2/24 dev eth1.200
ip link set dev eth1 up
ip link set dev eth1.100 up
ip link set dev eth1.200 up

# 4. PBR 라우팅 테이블 생성
grep -q -F '100 VRF_A' /etc/iproute2/rt_tables || echo "100 VRF_A" >> /etc/iproute2/rt_tables
grep -q -F '200 VRF_B' /etc/iproute2/rt_tables || echo "200 VRF_B" >> /etc/iproute2/rt_tables

# 5. 각 테이블에 반환 경로 설정
ip route add default via 192.168.100.1 dev eth1.100 table VRF_A
ip route add default via 192.168.200.1 dev eth1.200 table VRF_B

# 6. iptables 설정 (연결 추적 및 마킹)
iptables -t mangle -F PREROUTING
iptables -t nat -F POSTROUTING

# 6a. 들어오는 새 연결에 마킹
iptables -t mangle -A PREROUTING -i eth1.100 -m conntrack --ctstate NEW -j CONNMARK --set-mark 100
iptables -t mangle -A PREROUTING -i eth1.200 -m conntrack --ctstate NEW -j CONNMARK --set-mark 200

# 6b. 응답 패킷에 마크 복원
iptables -t mangle -A PREROUTING -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark

# 7. IP Rule 설정 (마크에 따른 테이블 매핑)
ip rule del fwmark 100 table VRF_A 2>/dev/null
ip rule del fwmark 200 table VRF_B 2>/dev/null
ip rule add fwmark 100 table VRF_A
ip rule add fwmark 200 table VRF_B

# 8. NAT (Masquerade) 및 Forwarding 허용
iptables -t nat -A POSTROUTING -s 172.16.0.0/16 -o eth0 -j MASQUERADE

iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth1.100 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth1.200 -o eth0 -j ACCEPT