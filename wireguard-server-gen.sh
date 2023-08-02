#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

WG_IPV6_PREFIX_LEN=64

WG_INTERFACE=wg0

WG_IPV6_NAT=false

DNS="1.1.1.1, 1.0.0.1"

WG_CLIENT_ALLOWED_IPS="1.0.0.0/8, 2.0.0.0/7, 4.0.0.0/6, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/3, 96.0.0.0/4, 112.0.0.0/5, 120.0.0.0/6, 124.0.0.0/7, 126.0.0.0/8, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/8, 169.0.0.0/9, 169.128.0.0/10, 169.192.0.0/11, 169.224.0.0/12, 169.240.0.0/13, 169.248.0.0/14, 169.252.0.0/15, 169.255.0.0/16, 170.0.0.0/7, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/10, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4, 224.0.0.0/4, 2000::/3"

if [ -f ".env" ]; then source .env; fi

if [ -d wgconfigs ]
then
    echo "Конифгурация сервера уже существует. Удалите директорию wgconfigs, чтобы создать новую конфигурацию!"
    exit 1
fi
mkdir wgconfigs
chmod 700 wgconfigs

# Вспомогательная функция для герерации IPv6 адресов
IPV6_ARRAY=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
gen_block () {
    echo ${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}
}

gen_block_2 () {
    echo ${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}
}

IPV6_ARRAY_SUFFIX_FIRST65=( 8 9 a b c d e f )
gen_block_suffix_first65 () {
    echo ${IPV6_ARRAY_SUFFIX_FISRT65[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}
}

echo generating server config
# generate the [Interface] part for the server
if [ -z "$WG_SERVER_ADDRESS" ]; then
    echo "Не задан адрес сервера"
    exit 2
fi
if [ -z "$PUBLIC_NETWORK_INTERFACE" ]; then
    echo "Не задан публичный интерфейс сервера"
    exit 3
fi
if [ -z "$WG_IPV4_PREFIX" ]; then
    WG_IPV4_PREFIX=10.$(shuf -i1-254 -n1).$(shuf -i1-254 -n1).
fi
if [ -z "$WG_IPV6_PREFIX" ]; then
    WG_IPV6_PREFIX=fd$(gen_block_2):$(gen_block):$(gen_block):$(gen_block):
fi
if [ -z "$WG_SERVER_PORT" ]; then
    WG_SERVER_PORT=$(shuf -i10000-65535 -n1)
fi
WG_SERVER_PRIVATE_KEY=$(wg genkey)
WG_SERVER_PUBLIC_KEY=$(echo "$WG_SERVER_PRIVATE_KEY" | wg pubkey)

if [ "$WG_IPV6_PREFIX_LEN" -eq 65 ]
then
    WG_SERVER_IPV6_SUFFIX=$(gen_block_suffix_first65):$(gen_block):$(gen_block):$(gen_block)
else
    WG_IPV6_PREFIX_LEN=64
    WG_SERVER_IPV6_SUFFIX=$(gen_block):$(gen_block):$(gen_block):$(gen_block)
fi

cat > wgconfigs/.env << EOF
WG_IPV4_PREFIX=${WG_IPV4_PREFIX}
WG_IPV6_PREFIX=${WG_IPV6_PREFIX}
WG_IPV6_PREFIX_LEN=${WG_IPV6_PREFIX_LEN}
WG_SERVER_PUBLIC_KEY=${WG_SERVER_PUBLIC_KEY}
WG_SERVER_ADDRESS=${WG_SERVER_ADDRESS}
WG_SERVER_PORT=${WG_SERVER_PORT}
WG_SERVER_INTERFACE=${WG_INTERFACE}
WG_CLIENT_ALLOWED_IPS="${WG_CLIENT_ALLOWED_IPS}"
DNS="${DNS}"
EOF
chmod 600 wgconfigs/.env

cat > wgconfigs/${WG_INTERFACE}.conf << EOF 
[Interface]
Address = ${WG_IPV4_PREFIX}1/24
Address = ${WG_IPV6_PREFIX}${WG_SERVER_IPV6_SUFFIX}/${WG_IPV6_PREFIX_LEN}
SaveConfig = true
ListenPort = ${WG_SERVER_PORT}
PrivateKey = ${WG_SERVER_PRIVATE_KEY}
PostUp = iptables -A FORWARD -i %i -j ACCEPT -w 10; iptables -t nat -A POSTROUTING -o ${PUBLIC_NETWORK_INTERFACE} -j MASQUERADE -w 10
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${PUBLIC_NETWORK_INTERFACE} -j MASQUERADE
EOF
chmod 600 wgconfigs/${WG_INTERFACE}.conf

if [ "$WG_IPV6_NAT" = "true" ]; then
cat >> wgconfigs/${WG_INTERFACE}.conf << EOF 
PostUp = ip6tables -A FORWARD -i %i -j ACCEPT; ip6tables -t nat -A POSTROUTING -o ${PUBLIC_NETWORK_INTERFACE} -j MASQUERADE -w 10
PostDown = ip6tables -D FORWARD -i %i -j ACCEPT; ip6tables -t nat -D POSTROUTING -o ${PUBLIC_NETWORK_INTERFACE} -j MASQUERADE
EOF
fi

exit 0