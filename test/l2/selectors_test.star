_selectors = import_module("/src/l2/selectors.star")


def test_l2_selectors_get_sequencers_params(plan):
    expect.eq(_selectors.get_sequencers_params([]), [])

    expect.eq(
        _selectors.get_sequencers_params(
            [
                struct(name="a", sequencer=True),
                struct(name="b", sequencer="a"),
                struct(name="c", sequencer=True),
                struct(name="d", sequencer="c"),
            ]
        ),
        [struct(name="a", sequencer=True), struct(name="c", sequencer=True)],
    )


def test_l2_selectors_is_sequencer(plan):
    expect.eq(_selectors.is_sequencer(struct(sequencer=True)), True)
    expect.eq(_selectors.is_sequencer(struct(sequencer="node0")), False)
    expect.eq(_selectors.is_sequencer(struct(sequencer=None)), False)
    expect.eq(_selectors.is_sequencer(struct(sequencer=False)), False)
