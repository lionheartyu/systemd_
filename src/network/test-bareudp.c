/* SPDX-License-Identifier: LGPL-2.1-or-later */

#include <linux/if_link.h>

#include "sd-netlink.h"

#include "bareudp.h"
#include "netlink-internal.h"
#include "tests.h"

TEST(bare_udp_fill_message_min_source_port) {
        _cleanup_(sd_netlink_message_unrefp) sd_netlink_message *message = NULL;
        sd_netlink rtnl = {
                .protocol = NETLINK_ROUTE,
        };
        BareUDP bare_udp = {
                .meta = {
                        .kind = NETDEV_KIND_BAREUDP,
                        .state = NETDEV_STATE_LOADING,
                },
                .iftype = BARE_UDP_PROTOCOL_IPV4,
                .dest_port = 4789,
                .min_port = 40000,
        };
        uint16_t min_port;

        ASSERT_OK(sd_rtnl_message_new_link(&rtnl, &message, RTM_NEWLINK, /* ifindex= */ 0));
        ASSERT_OK(sd_netlink_message_open_container(message, IFLA_LINKINFO));
        ASSERT_OK(sd_netlink_message_open_container_union(message, IFLA_INFO_DATA, "bareudp"));
        ASSERT_OK(bare_udp_vtable.fill_message_create(NETDEV(&bare_udp), NULL, message));
        ASSERT_OK(sd_netlink_message_close_container(message));
        ASSERT_OK(sd_netlink_message_close_container(message));

        ASSERT_OK(sd_netlink_message_rewind(message, &rtnl));
        ASSERT_OK(sd_netlink_message_enter_container(message, IFLA_LINKINFO));
        ASSERT_OK(sd_netlink_message_enter_container(message, IFLA_INFO_DATA));
        ASSERT_OK(sd_netlink_message_read_u16(message, IFLA_BAREUDP_SRCPORT_MIN, &min_port));
        ASSERT_EQ(min_port, htobe16(40000));
}

DEFINE_TEST_MAIN(LOG_INFO);
