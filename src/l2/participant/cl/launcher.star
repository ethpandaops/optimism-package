_hildr_launcher = import_module("/src/cl/hildr/launcher.star")


def launch(plan, params, network_params):
    service = None

    if params.type == "hildr":
        return _hildr_launcher.launch(plan=plan, params=params)
