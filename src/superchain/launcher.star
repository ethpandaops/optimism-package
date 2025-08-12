_file = import_module("/src/util/file.star")


def launch(plan, params):
    return struct(
        dependency_set=_create_dependency_set_artifact(plan, params),
    )


def _create_dependency_set_artifact(plan, params):
    return struct(
        artifact=_file.from_string(
            plan=plan,
            path=params.dependency_set.path,
            contents=json.encode(params.dependency_set.value),
            artifact_name=params.dependency_set.name,
            description="Creating a dependency set file {} for op-superchain {}".format(
                params.dependency_set.path, params.name
            ),
        ),
        superchain=params.name,
        path=params.dependency_set.path,
    )
