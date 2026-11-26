#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 || ! $1 =~ ^([1-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])$ ]]; then
    echo "Usage: $0 <host-id: 1-254>" >&2
    exit 2
fi

readonly HOST_ID="$1"
readonly BOND="bond0"
readonly MEMBERS=(eth1 eth2)
readonly VLAN_IDS=(10 20 30 40 50 60 70 80 90 100)

for iface in "${MEMBERS[@]}"; do
    if ! ip link show dev "$iface" >/dev/null 2>&1; then
        echo "Required interface $iface is missing" >&2
        exit 1
    fi
done

if ! ip link show dev "$BOND" >/dev/null 2>&1; then
    ip link add "$BOND" type bond mode 802.3ad lacp_rate slow
fi

for iface in "${MEMBERS[@]}"; do
    link_info="$(ip -o link show dev "$iface")"
    if [[ "$link_info" != *" master $BOND "* ]]; then
        ip link set dev "$iface" down
        ip link set dev "$iface" master "$BOND"
    fi
    ip link set dev "$iface" up
done
ip link set dev "$BOND" up

for vlan in "${VLAN_IDS[@]}"; do
    namespace="ns-vlan${vlan}"
    vlan_iface="${BOND}.${vlan}"
    ipv4="10.10.${vlan}.${HOST_ID}/24"
    ipv6="2001:db8:10:${vlan}::${HOST_ID}/64"
    gateway_ipv4="10.10.${vlan}.254"
    gateway_ipv6="2001:db8:10:${vlan}::254"

    if ! ip netns list | grep -qE "^${namespace}([[:space:]]|$)"; then
        ip netns add "$namespace"
    fi
    ip -n "$namespace" link set dev lo up

    if ip -n "$namespace" link show dev "$vlan_iface" >/dev/null 2>&1; then
        : # The VLAN interface is already in its namespace.
    elif ip link show dev "$vlan_iface" >/dev/null 2>&1; then
        ip link set dev "$vlan_iface" netns "$namespace"
    else
        ip link add link "$BOND" name "$vlan_iface" type vlan id "$vlan"
        ip link set dev "$vlan_iface" netns "$namespace"
    fi

    ip -n "$namespace" link set dev "$vlan_iface" up
    ip -n "$namespace" address replace "$ipv4" dev "$vlan_iface"
    ip -n "$namespace" -6 address replace "$ipv6" dev "$vlan_iface"
    ip -n "$namespace" route replace default via "$gateway_ipv4" dev "$vlan_iface"
    ip -n "$namespace" -6 route replace default via "$gateway_ipv6" dev "$vlan_iface"

    echo "$namespace: $vlan_iface $ipv4 $ipv6; default via $gateway_ipv4 and $gateway_ipv6"
done
