utils = import_module("/src/util.star")

def build_config_struct(l1_rpc, l2s_params):
    # You can optionally also include the l2 consensus endpoints here

    sequencers = {}
    for idx, l2 in enumerate(l2s_params):
        sequencers["seq{}".format(idx)] = {
            "noop": {
                "chainID": l2.network_params.network_id,
                "builder": "builder",
                "signer": "signer",
                "committer": "committer",
                "publisher": "publisher",
                "sequencer_conf_depth": 1,
                "sequencer_enabled": True,
                "sequencer_stopped": False,
                "sequencer_max_safe_lag": 0,
            }
        }

    return {
        "endpoints": [l1_rpc],
        "builders": {"builder": {"noop": {}}},
        "signers": {"signer": {"noop": {}}},
        "committers": {"committer": {"noop": {}}},
        "publishers": {"publisher": {"noop": {}}},
        "sequencers": sequencers,
    }


def generate_config_file(plan, l1_rpc, l2s_params, file_name="builder_config.yaml"):
    cfg = build_config_struct(l1_rpc, l2s_params)
    cfg_contents = yaml.encode(cfg)
    print("Generated Config:\n" + cfg_contents)
    return utils.write_to_file(
        plan=plan,
        contents=cfg_contents,
        directory="/config",
        file_name=file_name,
     )
