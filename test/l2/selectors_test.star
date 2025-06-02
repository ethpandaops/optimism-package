_selectors = import_module("/src/l2/selectors.star")


def test_l2_selectors_get_sequencers_params(plan):
    expect.eq(_selectors.get_sequencers_params([]), [])

    expect.eq(
        _selectors.get_sequencers_params(
            [
                struct(name="a", sequencer="a"),
                struct(name="b", sequencer="a"),
                struct(name="c", sequencer="c"),
                struct(name="d", sequencer="c"),
            ]
        ),
        [struct(name="a", sequencer="a"), struct(name="c", sequencer="c")],
    )


def test_l2_selectors_is_sequencer(plan):
    expect.eq(_selectors.is_sequencer(struct(sequencer="node0", name="node0")), True)
    expect.eq(_selectors.is_sequencer(struct(sequencer="node0", name="node1")), False)


def test_l2_selectors_create_get_sequencer_params_for_empty(plan):
    get_sequencer_params_for = _selectors.create_get_sequencer_params_for([])

    expect.fails(
        lambda: get_sequencer_params_for(
            struct(sequencer="a lot", name="node that's there")
        ),
        "Failed to get sequencer for node that's there: missing sequencer a lot",
    )


def test_l2_selectors_create_get_sequencer_params_for_no_sequencer(plan):
    get_sequencer_params_for = _selectors.create_get_sequencer_params_for([])

    expect.fails(
        lambda: get_sequencer_params_for(
            struct(sequencer="", name="node that's there")
        ),
        "Empty sequencer property on participant params for node that's there - this property should always contain a string name of the associated sequencer",
    )
    expect.fails(
        lambda: get_sequencer_params_for(
            struct(sequencer=None, name="node that's there")
        ),
        "Empty sequencer property on participant params for node that's there - this property should always contain a string name of the associated sequencer",
    )


def test_l2_selectors_create_get_sequencer_params_for_not_a_sequencer(plan):
    node_params = struct(name="who's not a sequencer", sequencer="somebody else")
    expect.true(not _selectors.is_sequencer(node_params))

    get_sequencer_params_for = _selectors.create_get_sequencer_params_for([node_params])

    expect.fails(
        lambda: get_sequencer_params_for(
            struct(sequencer="who's not a sequencer", name="node that's there")
        ),
        "Failed to get sequencer for node that's there: missing sequencer who's not a sequencer",
    )


def test_l2_selectors_create_get_sequencer_params_for_a_sequencer(plan):
    node_params = struct(name="a sequencer", sequencer="a sequencer")
    expect.true(_selectors.is_sequencer(node_params))

    get_sequencer_params_for = _selectors.create_get_sequencer_params_for([node_params])

    expect.eq(get_sequencer_params_for(struct(sequencer="a sequencer")), node_params)
