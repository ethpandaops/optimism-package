def create():
    __self_ref = [None]
    __items_by_id = {}

    def __self():
        return __self_ref[0]

    def add(*items):
        for item in items:
            _assert_item(item)

            if __items_by_id.get(item.id):
                fail("Failed to add item {}: item with the same ID already exists")

            __items_by_id[item.id] = item

        return __self()

    # This function returns the items in the order they should be launched
    # based on their dependencies.
    #
    # It will try to preserve the order in which the items were added,
    # only reordering them if necessary to satisfy the dependencies.
    #
    # If there are any cycles in the dependencies, it will fail.
    # If there are any missing dependencies, it will also fail.
    def sequence():
        # First we check whether we have all the items
        all_dependency_ids = [
            dependency
            for item in __items_by_id.values()
            for dependency in item.dependencies
        ]

        # Now check we have all of them
        missing_dependency_ids = [
            id for id in all_dependency_ids if id not in __items_by_id
        ]
        if missing_dependency_ids:
            fail(
                "Failed to launch: Missing items {}".format(
                    ",".join(missing_dependency_ids)
                )
            )

        # Now we have to order the items based on their dependencies
        #
        # First we start with the default sequence - the order in which the items were added
        ordered_items = __items_by_id.values()
        num_items = len(ordered_items)

        for index in range(num_items):
            item = ordered_items[index]

            # Since we are not allowed any unbound loops, we'll have to resort to somewhat different strategy
            #
            # We will calculate the lowest index at which this item can be placed
            # based on its dependencies.
            lowest_desired_index = _lowest_desired_index(item, ordered_items)

            # If the lowest index is lower or equal to the current index, everything is fine and we can continue
            if lowest_desired_index <= index:
                continue

            # If the lowest index is greater than the current index, we need to swap the item with the item at the lowest index
            item_to_swap = ordered_items[lowest_desired_index]

            # We cannot just swap thew though - we also need to check that the item being swapped in is not dependent on the item being swapped out
            #
            # We do this by checking the lowest desired index for the item being swapped in,
            # and if it is greater than the current index, we fail
            #
            # In other words, if the item we want to swap with the current item is dependent on the current item,
            # we cannot swap them because we have a cycle
            lowest_desired_index_for_item_to_swap = _lowest_desired_index(
                item_to_swap, ordered_items
            )

            if lowest_desired_index_for_item_to_swap > index:
                fail(
                    "Cannot create launch sequence: Item {} <-> {}".format(
                        item.id, item_to_swap.id
                    )
                )

            ordered_items[index] = item_to_swap
            ordered_items[lowest_desired_index] = item

        return ordered_items

    __self_ref[0] = struct(
        add=add,
        sequence=sequence,
    )

    return __self()


# Launches a scheule by executing each item in the order determined by the schedule.
def launch(plan, schedule):
    items = schedule.sequence()
    launched = {}

    for item in items:
        missing_dependencies = [id for id in item.dependencies if id not in launched]
        if missing_dependencies:
            fail(
                "schedule: Launch error: Missing dependencies {} for item {}".format(
                    ",".join(missing_dependencies),
                    item.id,
                )
            )

        # We will always only pass the explicitly defined dependencies
        item_dependencies = {id: launched[id] for id in item.dependencies}

        launched[item.id] = item.launch(plan=plan, dependencies=item_dependencies)

    return launched


def item(id, launch, dependencies=[]):
    return _assert_item(
        struct(
            id=id,
            launch=launch,
            dependencies=dependencies,
        )
    )


def _lowest_desired_index(item, items):
    items_without_item = list(items)
    items_without_item.remove(item)

    for index in range(len(items)):
        previous_items = items_without_item[:index]
        previous_ids = [i.id for i in previous_items]

        missing_dependencies = [
            id for id in item.dependencies if id not in previous_ids
        ]

        if not missing_dependencies:
            return index


def _assert_item(item):
    type_of_item = type(item)
    if type_of_item != "struct":
        fail(
            "schedule: Expected an item to be a struct, got {} of type {}".format(
                item, type_of_item
            )
        )

    if not hasattr(item, "id"):
        fail(
            "schedule: Expected an item to have a property 'id', got {}".format(
                item, type_of_item
            )
        )

    type_of_id = type(item.id)
    if type_of_id != "string":
        fail(
            "schedule: Expected an item to have an 'id' of type string but 'id' is of type {}".format(
                type_of_id
            )
        )

    if not hasattr(item, "dependencies"):
        fail(
            "schedule: Expected an item to have a property 'dependencies', got {}".format(
                item, type_of_item
            )
        )

    type_of_dependencies = type(item.dependencies)
    if type_of_dependencies != "list":
        fail(
            "schedule: Expected an item to have a 'dependencies' property of type list but 'dependencies' is of type {}".format(
                type_of_dependencies
            )
        )

    mistyped_dependencies = [d for d in item.dependencies if type(d) != "string"]
    if mistyped_dependencies:
        fail(
            "schedule: Expected an item to have a 'dependencies' property of type list of strings but 'dependencies' contains {}".format(
                ", ".join(
                    ["{} of type {}".format(d, type(d)) for d in mistyped_dependencies]
                )
            )
        )

    has_self_as_dependency = item.id in item.dependencies
    if has_self_as_dependency:
        fail("schedule: Item {} specifies itself as its dependency".format(item.id))

    if not hasattr(item, "launch"):
        fail(
            "schedule: Expected an item to have a property 'launch', got {}".format(
                item, type_of_item
            )
        )

    type_of_launch = type(item.launch)
    if type_of_launch != "function":
        fail(
            "schedule: Expected an item to have a 'launch' property of type function but 'launch' is of type {}".format(
                type_of_launch
            )
        )

    return item
