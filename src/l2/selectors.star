_filter = import_module("/src/util/filter.star")


def get_sequencers_params(participants_params):
    return [p for p in participants_params if is_sequencer(p)]


def create_get_sequencer_params_for(participants_params):
    def get_sequencer_params_for(participant_params):
        sequencer_params = _filter.first(
            get_sequencers_params(participants_params),
            lambda p: p.name == participant_params.sequencer,
        )

        return (
            sequencer_params
            if sequencer_params
            else fail(
                "Failed to get sequencer for {}: missing sequencer {}".format(
                    participant_params.name, participant_params.sequencer
                )
            )
        )

    return get_sequencer_params_for


def is_sequencer(participant_params):
    return participant_params.sequencer == participant_params.name
