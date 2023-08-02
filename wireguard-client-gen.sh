if [ -f "wgconfigs/.env" ]
then
    source wgconfigs/.env
else
    echo "Wireguard Server config not found";
    exit 1;
fi

# Вспомогательная функция для герерации IPv6 адресов
IPV6_ARRAY=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
gen_block () {
    echo ${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}
}

IPV6_ARRAY_SUFFIX_FIRST65=( 8 9 a b c d e f )
gen_block_suffix_first65 () {
    echo ${IPV6_ARRAY_SUFFIX_FISRT65[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}${IPV6_ARRAY[$RANDOM%16]}
}

if [ ! -f wgconfigs/client_ip_suffix.txt ]; then
    CLIENT_IP_SUFFIX=2
else
    read CLIENT_IP_SUFFIX < wgconfigs/client_ip_suffix.txt
fi
if [ "$WG_IPV6_PREFIX_LEN" -eq 65 ]
then
    CLIENT_IP6_SUFFIX=$(gen_block_suffix_first65):$(gen_block):$(gen_block):$(gen_block)
else
    WG_IPV6_PREFIX_LEN=64
    CLIENT_IP6_SUFFIX=$(gen_block):$(gen_block):$(gen_block):$(gen_block)
fi
mkdir -p wgconfigs/clientconfigs
chmod 700 wgconfigs/clientconfigs

echo generating client config w/ IP ${WG_IPV4_PREFIX}${CLIENT_IP_SUFFIX}, ${WG_IPV6_PREFIX}${CLIENT_IP6_SUFFIX}

WG_CLIENT_PRIVATE_KEY=$(wg genkey)
WG_CLIENT_PUBLIC_KEY=$(echo "$WG_CLIENT_PRIVATE_KEY" | wg pubkey)
WG_CLIENT_PSK=$(wg genpsk)

cat > wgconfigs/clientconfigs/${WG_SERVER_INTERFACE}c${CLIENT_IP_SUFFIX}.conf << EOF 
[Interface]
Address = ${WG_IPV4_PREFIX}${CLIENT_IP_SUFFIX}/32,${WG_IPV6_PREFIX}${CLIENT_IP6_SUFFIX}/128
PrivateKey = ${WG_CLIENT_PRIVATE_KEY}
DNS = ${DNS}

[Peer]
PublicKey = ${WG_SERVER_PUBLIC_KEY}
PresharedKey = ${WG_CLIENT_PSK}
Endpoint = ${WG_SERVER_ADDRESS}:${WG_SERVER_PORT}
AllowedIPs = ${WG_CLIENT_ALLOWED_IPS}
EOF
chmod 600 wgconfigs/clientconfigs/${WG_SERVER_INTERFACE}c${CLIENT_IP_SUFFIX}.conf

# add a peer to server config
cat >> wgconfigs/${WG_SERVER_INTERFACE}.conf << EOF 

[Peer]
PublicKey = ${WG_CLIENT_PUBLIC_KEY}
PresharedKey = ${WG_CLIENT_PSK}
AllowedIPs = ${WG_IPV4_PREFIX}${CLIENT_IP_SUFFIX}/32,${WG_IPV6_PREFIX}${CLIENT_IP6_SUFFIX}/128
EOF

CLIENT_IP_SUFFIX=$[$CLIENT_IP_SUFFIX+1]
echo $CLIENT_IP_SUFFIX > wgconfigs/client_ip_suffix.txt

exit 0