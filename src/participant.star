def new_participant(
    el_type,
    cl_type,
    el_context,
    cl_context,
):
    return struct(
        el_type=el_type,
        cl_type=cl_type,
        el_context=el_context,
        cl_context=cl_context,
    )
