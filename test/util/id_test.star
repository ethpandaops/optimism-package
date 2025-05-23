_id = import_module("/src/util/id.star")


def test_id_autoincrement_default_initial_value(plan):
    id = _id.autoincrement()

    expect.eq(id(), 1)
    expect.eq(id(), 2)
    expect.eq(id(), 3)
    expect.eq(id(), 4)


def test_id_autoincrement_custom_initial_value(plan):
    id = _id.autoincrement(1000)

    expect.eq(id(), 1000)
    expect.eq(id(), 1001)
    expect.eq(id(), 1002)
    expect.eq(id(), 1003)
    expect.eq(id(), 1004)
