util = import_module("/src/util.star")


def test_label_from_image_short_image_name(plan):
    image_name = "my-image"
    image_label = util.label_from_image(image_name)

    expect.eq(image_name, image_label)


def test_label_from_image_63_character_image_name(plan):
    image_name = ("tenletters" * 6) + "333"
    expect.eq(len(image_name), 63)

    image_label = util.label_from_image(image_name)
    expect.eq(len(image_label), 63)
    expect.eq(image_name, image_label)


def test_label_from_image_64_character_image_name_no_slashes(plan):
    image_name = ("tenletters" * 6) + "4444"
    expect.eq(len(image_name), 64)

    image_label = util.label_from_image(image_name)
    expect.eq(len(image_label), 63)
    expect.eq(image_name[-63:], image_label)


def test_label_from_image_long_image_name_no_slashes(plan):
    image_name = "tenletters" * 10
    expect.eq(len(image_name), 100)

    image_label = util.label_from_image(image_name)
    expect.eq(len(image_label), 63)
    expect.eq(image_name[-63:], image_label)


def test_label_from_image_long_image_name_one_slash(plan):
    image_suffix = "444"
    image_name = "/".join(["tenletters" * 6, image_suffix])

    image_label = util.label_from_image(image_name)
    expect.eq(image_suffix, image_label)


def test_label_from_image_long_image_name_more_slashes(plan):
    image_suffix = "/".join(["slash", "slash2", "slash3"])
    image_name = "/".join(["tenletters" * 8, image_suffix])

    image_label = util.label_from_image(image_name)
    expect.eq(image_suffix, image_label)


def test_label_from_image_long_image_name_long_suffix(plan):
    image_suffix = "/".join(["slash", "slash2", "slash3", "what-a-suffix" * 5])
    image_name = "/".join(["tenletters" * 8, image_suffix])

    image_label = util.label_from_image(image_name)
    expect.eq(len(image_label), 63)
    expect.eq(image_suffix[-63:], image_label)


def test_filter_none(plan):
    expect.eq(util.filter_none({}), {})
    expect.eq(util.filter_none({"key": "value"}), {"key": "value"})
    expect.eq(util.filter_none({"key": None}), {})
    expect.eq(util.filter_none({"key": False}), {"key": False})
    expect.eq(util.filter_none({"key": 0}), {"key": 0})
    expect.eq(util.filter_none({"key": ""}), {"key": ""})
    expect.eq(util.filter_none({"key": []}), {"key": []})
    expect.eq(util.filter_none({"key": {}}), {"key": {}})


def test_get_duplicates(plan):
    expect.eq(util.get_duplicates([]), [])
    expect.eq(util.get_duplicates([1]), [])
    expect.eq(util.get_duplicates([1, 1]), [1])
    expect.eq(util.get_duplicates([1, 1, 1, 2, 2, 2, 3]), [1, 2])
    expect.eq(util.get_duplicates([1, 2, "1"]), [])
    expect.eq(util.get_duplicates([{}, {}]), [{}])
    expect.eq(util.get_duplicates([{}, {"key": "value"}]), [])
    expect.eq(util.get_duplicates([[1], [1]]), [[1]])
