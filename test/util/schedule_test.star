_schedule = import_module("/src/util/schedule.star")


def _default_launch(plan, dependencies):
    return None


def test_util_schedule_dependency_invalid_item(plan):
    schedule = _schedule.create()

    # We check for a missing id
    expect.fails(
        lambda: schedule.add(struct()),
        "schedule: Expected an item to have a property 'id'",
    )

    # We check for a mistyped id
    expect.fails(
        lambda: schedule.add(struct(id=123)),
        "schedule: Expected an item to have an 'id' of type string but 'id' is of type int",
    )

    # We check for missing dependencies
    expect.fails(
        lambda: schedule.add(struct(id="a", launch=_default_launch)),
        "schedule: Expected an item to have a property 'dependencies'",
    )

    # We check for mistyped dependencies
    expect.fails(
        lambda: schedule.add(struct(id="a", launch=_default_launch, dependencies="b")),
        "schedule: Expected an item to have a 'dependencies' property of type list but 'dependencies' is of type string",
    )

    # We check for mistyped dependencies
    expect.fails(
        lambda: schedule.add(
            struct(id="a", launch=_default_launch, dependencies=[123, [], {}, False])
        ),
        "schedule: Expected an item to have a 'dependencies' property of type list of strings but 'dependencies' contains 123 of type int, \\[\\] of type list, \\{\\} of type dict, False of type bool",
    )

    # We check for missing launch
    expect.fails(
        lambda: schedule.add(struct(id="a", dependencies=["b"])),
        "schedule: Expected an item to have a property 'launch'",
    )

    # We check for mistyped launch
    expect.fails(
        lambda: schedule.add(struct(id="a", launch=123, dependencies=["b"])),
        "schedule: Expected an item to have a 'launch' property of type function but 'launch' is of type int",
    )


def test_util_schedule_dependency_on_self(plan):
    schedule = _schedule.create()

    # We check whether the item() utility function catches this
    expect.fails(
        lambda: _schedule.item(id="a", launch=_default_launch, dependencies=["a"]),
        "schedule: Item a specifies itself as its dependency",
    )

    # And whether the schedule.add() function catches this
    expect.fails(
        lambda: schedule.add(
            struct(id="a", launch=_default_launch, dependencies=["a"])
        ),
        "schedule: Item a specifies itself as its dependency",
    )


def test_util_schedule_no_dependencies(plan):
    schedule = _schedule.create()

    item_a = _schedule.item(id="a", launch=_default_launch)
    item_b = _schedule.item(id="b", launch=_default_launch)

    schedule.add(item_b)
    schedule.add(item_a)

    expect.eq(schedule.sequence(), [item_b, item_a])


def test_util_schedule_simple_linear_dependencies(plan):
    schedule = _schedule.create()

    item_a = _schedule.item(id="a", launch=_default_launch)
    item_b = _schedule.item(id="b", launch=_default_launch, dependencies=["a"])

    schedule.add(item_b)
    schedule.add(item_a)

    expect.eq(schedule.sequence(), [item_a, item_b])


def test_util_schedule_simple_simple_cycle_dependencies(plan):
    schedule = _schedule.create()

    item_a = _schedule.item(id="a", launch=_default_launch, dependencies=["b"])
    item_b = _schedule.item(id="b", launch=_default_launch, dependencies=["a"])

    schedule.add(item_b)
    schedule.add(item_a)

    expect.fails(
        lambda: schedule.sequence(), "Cannot create launch sequence: Item b <-> a"
    )


def test_util_schedule_simple_large_cycle_dependencies(plan):
    schedule = _schedule.create()

    item_a = _schedule.item(id="a", launch=_default_launch, dependencies=["d"])
    item_b = _schedule.item(id="b", launch=_default_launch, dependencies=["a"])
    item_c = _schedule.item(id="c", launch=_default_launch, dependencies=["b"])
    item_d = _schedule.item(id="d", launch=_default_launch, dependencies=["a"])

    schedule.add(item_b)
    schedule.add(item_a)
    schedule.add(item_c)
    schedule.add(item_d)

    expect.fails(
        lambda: schedule.sequence(), "Cannot create launch sequence: Item b <-> a"
    )


def test_util_schedule_simple_branching_dependencies(plan):
    schedule = _schedule.create()

    item_a = _schedule.item(id="a", launch=_default_launch)
    item_b = _schedule.item(id="b", launch=_default_launch)
    item_c1 = _schedule.item(id="c1", launch=_default_launch, dependencies=["b"])
    item_c2 = _schedule.item(id="c2", launch=_default_launch, dependencies=["b"])
    item_c21 = _schedule.item(id="c21", launch=_default_launch, dependencies=["c2"])
    item_c22 = _schedule.item(id="c22", launch=_default_launch, dependencies=["c21"])
    item_c3 = _schedule.item(id="c3", launch=_default_launch, dependencies=["b"])
    item_d = _schedule.item(
        id="d", launch=_default_launch, dependencies=["c1", "c22", "c3"]
    )

    schedule.add(item_b)
    schedule.add(item_c1)
    schedule.add(item_d)
    schedule.add(item_c21)
    schedule.add(item_c22)
    schedule.add(item_a)
    schedule.add(item_c3)
    schedule.add(item_c2)

    expect.eq(
        schedule.sequence(),
        [item_b, item_c1, item_c3, item_c2, item_c21, item_a, item_c22, item_d],
    )


def test_util_schedule_launch_empty(plan):
    schedule = _schedule.create()

    # Launching an empty schedule should return an empty dict
    expect.eq(_schedule.launch(plan, schedule), {})


def test_util_schedule_launch_simple(plan):
    schedule = _schedule.create()

    schedule.add(
        _schedule.item(
            id="a",
            launch=lambda plan, dependencies: "a launched with dependencies {}".format(
                dependencies
            ),
        )
    )
    schedule.add(
        _schedule.item(
            id="b",
            launch=lambda plan, dependencies: "b launched with dependencies {}".format(
                dependencies
            ),
            dependencies=["a"],
        )
    )

    expect.eq(
        _schedule.launch(plan, schedule),
        {
            "a": "a launched with dependencies {}",
            "b": 'b launched with dependencies {"a": "a launched with dependencies {}"}',
        },
    )


def test_util_schedule_launch_branching(plan):
    schedule = _schedule.create()

    schedule.add(
        _schedule.item(
            id="a",
            launch=lambda plan, dependencies: "a launched with dependencies {}".format(
                dependencies
            ),
        )
    )
    schedule.add(
        _schedule.item(
            id="b",
            launch=lambda plan, dependencies: "b launched with dependencies {}".format(
                dependencies
            ),
            dependencies=["a"],
        )
    )
    schedule.add(
        _schedule.item(
            id="c1",
            launch=lambda plan, dependencies: "c1 launched with dependencies {}".format(
                dependencies
            ),
            dependencies=["b"],
        )
    )
    schedule.add(
        _schedule.item(
            id="c2",
            launch=lambda plan, dependencies: "c2 launched with dependencies {}".format(
                dependencies
            ),
            dependencies=["b"],
        )
    )
    schedule.add(
        _schedule.item(
            id="d",
            launch=lambda plan, dependencies: "d launched with dependencies {}".format(
                dependencies
            ),
            dependencies=["c1", "c2"],
        )
    )

    expect.eq(
        _schedule.launch(plan, schedule),
        {
            "a": "a launched with dependencies {}",
            "b": 'b launched with dependencies {"a": "a launched with dependencies {}"}',
            "c1": 'c1 launched with dependencies {"a": "a launched with dependencies {}", "b": "b launched with dependencies {\\"a\\": \\"a launched with dependencies {}\\"}"}',
            "c2": 'c2 launched with dependencies {"a": "a launched with dependencies {}", "b": "b launched with dependencies {\\"a\\": \\"a launched with dependencies {}\\"}", "c1": "c1 launched with dependencies {\\"a\\": \\"a launched with dependencies {}\\", \\"b\\": \\"b launched with dependencies {\\\\\\"a\\\\\\": \\\\\\"a launched with dependencies {}\\\\\\"}\\"}"}',
            "d": 'd launched with dependencies {"a": "a launched with dependencies {}", "b": "b launched with dependencies {\\"a\\": \\"a launched with dependencies {}\\"}", "c1": "c1 launched with dependencies {\\"a\\": \\"a launched with dependencies {}\\", \\"b\\": \\"b launched with dependencies {\\\\\\"a\\\\\\": \\\\\\"a launched with dependencies {}\\\\\\"}\\"}", "c2": "c2 launched with dependencies {\\"a\\": \\"a launched with dependencies {}\\", \\"b\\": \\"b launched with dependencies {\\\\\\"a\\\\\\": \\\\\\"a launched with dependencies {}\\\\\\"}\\", \\"c1\\": \\"c1 launched with dependencies {\\\\\\"a\\\\\\": \\\\\\"a launched with dependencies {}\\\\\\", \\\\\\"b\\\\\\": \\\\\\"b launched with dependencies {\\\\\\\\\\\\\\"a\\\\\\\\\\\\\\": \\\\\\\\\\\\\\"a launched with dependencies {}\\\\\\\\\\\\\\"}\\\\\\"}\\"}"}',
        },
    )
