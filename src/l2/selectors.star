def get_sequencers_params(participants_params):
    return [p for p in participants_params if is_sequencer(p)]


def is_sequencer(participant_params):
    return participant_params.sequencer == participant_params.name
