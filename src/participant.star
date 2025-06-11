def new_participant(
    el_type,
    cl_type,
    el_context,
    cl_context,
    sidecar_context=None,
):
    return struct(
        el_type=el_type,
        cl_type=cl_type,
        el_context=el_context,
        cl_context=cl_context,
        sidecar_context=sidecar_context,
    )
