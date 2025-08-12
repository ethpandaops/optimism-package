_filter = import_module("./filter.star")


# from_string creates a file artifact from a static string
def from_string(plan, path, contents, artifact_name=None, description=None):
    # We'll need to escape anything that go might interpret as template braces
    #
    # We are limited with the replace function - we would need to run replace twice,
    # once for each bracket type BUT the result of the first replace would introduce
    # braces that do not need to be escaped (and would result in an invalid template)
    #
    # Because of this, we'll first split the template into segments delimited by "{{", then run replace on each segment for "}}",
    # then we rejoin the template with the "{{" substitution
    escaped_contents = "{{ `{{` }}".join(
        [segment.replace("}}", "{{ `}}` }}") for segment in contents.split("{{")]
    )

    kwargs = _filter.remove_none({"name": artifact_name, "description": description})

    return plan.render_templates(
        config={
            path: struct(
                template=escaped_contents,
                data={},
            ),
        },
        **kwargs,
    )
