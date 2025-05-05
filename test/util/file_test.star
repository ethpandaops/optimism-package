file = import_module("/src/util/file.star")


def test_file_from_string_simple_template(plan):
    render_templates_mock = kurtosistest.mock(plan, "render_templates")

    file_artifact = file.from_string(plan, "/path", "{{.Name}}")
    expect.eq(
        render_templates_mock.calls(),
        [
            struct(
                args=[],
                kwargs={
                    "config": {
                        "/path": struct(template="{{ `{{` }}.Name{{ `}}` }}", data={})
                    }
                },
                return_value=file_artifact,
            )
        ],
    )


def test_file_from_string_weird_template(plan):
    render_templates_mock = kurtosistest.mock(plan, "render_templates")

    file_artifact = file.from_string(plan, "/path", "{{{{.Name}} }{{")
    expect.eq(
        render_templates_mock.calls(),
        [
            struct(
                args=[],
                kwargs={
                    "config": {
                        "/path": struct(
                            template="{{ `{{` }}{{ `{{` }}.Name{{ `}}` }} }{{ `{{` }}",
                            data={},
                        )
                    }
                },
                return_value=file_artifact,
            )
        ],
    )


def test_file_from_string_optional_args(plan):
    render_templates_mock = kurtosistest.mock(plan, "render_templates")

    file_artifact = file.from_string(
        plan,
        "/path",
        "Hello!",
        artifact_name="My artifact",
        description="My description",
    )
    expect.eq(
        render_templates_mock.calls(),
        [
            struct(
                args=[],
                kwargs={
                    "config": {"/path": struct(template="Hello!", data={})},
                    "description": "My description",
                    "name": "My artifact",
                },
                return_value=file_artifact,
            )
        ],
    )
