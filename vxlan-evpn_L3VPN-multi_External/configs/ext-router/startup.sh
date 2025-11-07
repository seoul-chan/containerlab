#!/bin/sh

# 1. IP 포워딩 활성화
sysctl -w net.ipv4.ip_forward=1

# 2. Border Leaf(borderleaf1)와 연결되는 인터페이스 설정
ip addr add 192.168.100.2/24 dev eth1 # VRF A
ip addr add 192.168.200.2/24 dev eth2 # VRF B

# 3. PBR을 위한 별도 라우팅 테이블 생성
grep -q -F '100 VRF_A' /etc/iproute2/rt_tables || echo "100 VRF_A" >> /etc/iproute2/rt_tables
grep -q -F '200 VRF_B' /etc/iproute2/rt_tables || echo "200 VRF_B" >> /etc/iproute2/rt_tables

# 4. 각 PBR 테이블에 반환 경로(return route) 설정
ip route add default via 192.168.100.1 dev eth1 table VRF_A
ip route add default via 192.168.200.1 dev eth2 table VRF_B

# 5. Mangle 테이블 및 NAT 테이블 초기화
iptables -t mangle -F PREROUTING
iptables -t nat -F POSTROUTING

# 6. Mangle 규칙: 연결(Connection)에 표시하기
iptables -t mangle -A PREROUTING -i eth1 -m conntrack --ctstate NEW -j CONNMARK --set-mark 100
iptables -t mangle -A PREROUTING -i eth2 -m conntrack --ctstate NEW -j CONNMARK --set-mark 200
iptables -t mangle -A PREROUTING -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark

# 7. IP 규칙(Policy): "패킷 마크"에 따라 라우팅 테이블 결정
ip rule del fwmark 100 table VRF_A 2>/dev/null
ip rule del fwmark 200 table VRF_B 2>/dev/null
ip rule add fwmark 100 table VRF_A
ip rule add fwmark 200 table VRF_B

# 8. NAT 설정 (POSTROUTING)
# (소스 IP 대역을 명시해주는 것이 좋습니다)
iptables -t nat -A POSTROUTING -s 172.16.0.0/16 -o eth0 -j MASQUERADE

# 9. --- [신규] FORWARD 체인 허용 규칙 ---
# 9a. 이미 수립된 연결(응답 패킷)은 무조건 허용
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# 9b. VRF A(eth1)에서 외부(eth0)로 나가는 새 연결 허용
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
# 9c. VRF B(eth2)에서 외부(eth0)로 나가는 새 연결 허용
iptables -A FORWARD -i eth2 -o eth0 -j ACCEPT
# ------------------------------------