el_client_launcher = import_module("./el/el_launcher.star")
cl_client_launcher = import_module("./cl/cl_launcher.star")
participant_module = import_module("./participant.star")


def launch_participant_network(
    plan,
    participants,
    jwt_file,
    network_params,
    el_cl_data,
    gs_private_keys,
    l1_config_env_vars,
):
    num_participants = len(participants)
    # Launch all execution layer clients
    all_el_contexts = el_client_launcher.launch(
        plan,
        jwt_file,
        network_params,
        el_cl_data,
        participants,
        num_participants,
    )

    all_cl_contexts = cl_client_launcher.launch(
        plan,
        jwt_file,
        network_params,
        el_cl_data,
        participants,
        num_participants,
        all_el_contexts,
        l1_config_env_vars,
        gs_private_keys["GS_SEQUENCER_PRIVATE_KEY"],
    )

    all_participants = []
    for index, participant in enumerate(participants):
        el_type = participant.el_type
        cl_type = participant.cl_type

        el_context = all_el_contexts[index]
        cl_context = all_cl_contexts[index]

        participant_entry = participant_module.new_participant(
            el_type,
            cl_type,
            el_context,
            cl_context,
        )

        all_participants.append(participant_entry)

    # op_batcher_launcher.launch(
    #     plan,
    # )
    # participant_module.new_participant(

    # )
    # op_proposer_launcher.launch(

    # )

    return all_participants
