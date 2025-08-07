utils = import_module("/src/util.star")

def build_config_struct(l1_rpc, l2s_params):
    # You can optionally also include the l2 consensus endpoints here
#     builder_chain1 = {
#         "chain_id":  {"standard": {
#             "l1EL": l1_rpc,
#             "l2EL": "",
#             "l2CL": "",
#         }}
#     }
#
#     builder_chain2 = {
#             "chain_id":  {"standard": {
#                 "l1EL": "",
#                 "l2EL": "",
#                 "l2CL": "",
#             }}
#         }

    return {
        "endpoints": [],
        "builders": {"builder": {"noop": {}}},
        "signers": {"signer": {"noop": {}}},
        "committers": {"committer": {"noop": {}}},
        "publishers": {"publisher": {"noop": {}}},
        "sequencers": {"seq1":{"noop": {}}},
    }


def generate_config_file(plan, l1_rpc, l2s_params, file_name="builder_config.yaml"):
    cfg = build_config_struct(l1_rpc, l2s_params)
    cfg_contents = json.encode(cfg)
    plan.print("Generated Config:\n" + cfg_contents)
    return utils.write_to_file(
        plan=plan,
        contents=cfg_contents,
        directory="/config",
        file_name=file_name,
     )
