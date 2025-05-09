_file = import_module("/src/util/file.star")


def launch(plan, superchains_params):
    return {
        superchain_params.name: _create_dependency_set_artifact(plan, superchain_params)
        for superchain_params in (superchains_params or [])
    }


def _create_dependency_set_artifact(plan, superchain_params):
    return struct(
        artifact=_file.from_string(
            plan=plan,
            path=superchain_params.dependency_set.path,
            contents=json.encode(superchain_params.dependency_set.value),
            artifact_name=superchain_params.dependency_set.name,
            description="Creating a dependency set file {} for op-superchain {}".format(
                superchain_params.dependency_set.path, superchain_params.name
            ),
        ),
        superchain=superchain_params.name,
        path=superchain_params.dependency_set.path,
    )
