utils = import_module("/src/util.star")

def build_config_struct(plan, deployment_output, l1_rpc, l2s_params):
    builders = {}
    committers = {}
    signers = {}
    publishers = {}
    sequencers = {}

    for l2 in l2s_params:
        network_id = l2.network_params.network_id
        builder_id = "builder-{}".format(network_id)
        committer_id = "committer-{}".format(network_id)
        publisher_id = "publisher-{}".format(network_id)
        signer_id = "signer-{}".format(network_id)
        sequencer_id = "sequencer-{}".format(network_id)

        sequencer_private_key = utils.read_network_config_value(
            plan,
            deployment_output,
            "sequencer-{0}".format(network_id),
            ".privateKey",
        )

        # Extract EL and CL participant info
        el_participant = l2.participants[0].el
        cl_participant = l2.participants[0].cl

        l2_el_url = "http://{}:{}".format(
           el_participant.service_name,
           el_participant.ports["rpc"].number,
        )
        l2_cl_url = "http://{}:{}".format(
           cl_participant.service_name,
           cl_participant.ports["rpc"].number,
        )

        builders[builder_id] = {
            "standard": {
               "l1EL": l1_rpc,
               "l2EL": l2_el_url,
               "l2CL": l2_cl_url,
            }
        }

        committers[committer_id] = {
            "standard" : {
                "rpc" : l2_cl_url,
            }
        }

        publishers[publisher_id] = {
            "standard" : {
                "rpc" : l2_cl_url,
            }
        }

        signers[signer_id] = {
            "local-key" : {
                "chainID": network_id,
                "raw": sequencer_private_key,
            }
        }

        sequencers[sequencer_id]  = {
            "full" : {
                "chainID": network_id,
                "builder": builder_id,
                "signer": signer_id,
                "committer": committer_id,
                "publisher": publisher_id,
            }
        }

    return {
        "endpoints": [],
        "builders": builders,
        "signers": signers,
        "committers": committers,
        "publishers": publishers,
        "sequencers": sequencers
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
