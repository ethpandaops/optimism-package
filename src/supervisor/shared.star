_l2_selectors = import_module("/src/l2/selectors.star")

_net = import_module("/src/util/net.star")

# Helper utility to get interop RPC URLs for all CL nodes from all L2 networks
# 
# This encapsulates the logic required to get the URLs not only for the regular CLs
# but for the MEV CL builders as well
def get_cls_interop_rpc_urls(l2s_params, superchain_params):
    return [
        _net.service_url(
            cl.service_name,
            superchain_params.ports[_net.INTEROP_RPC_PORT_NAME],
        )
        # We go chain by chain
        for l2_params in l2s_params
        # Participant by participant
        for participant_params in l2_params.participants
        # And CL by CL
        for cl in _l2_selectors.get_cls_params(participant_params=participant_params)
    ]
