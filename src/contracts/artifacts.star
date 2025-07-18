def normalize_locator(locator):
    """Transform artifact locator from 'artifact://NAME' format to (name, file_path) pair.

    If the locator doesn't use the artifact:// format, returns (None, original_locator).

    Args:
        locator: The original artifact locator string

    Returns:
        tuple: (artifact_name, normalized_locator, mount_point)
    """
    if locator and locator.startswith("artifact://"):
        artifact_name = locator[len("artifact://") :]
        mount_point = "/{0}".format(artifact_name)
        return (artifact_name, "file://{0}".format(mount_point), mount_point)
    return (None, locator, None)


def normalize_locators(plan, l1_locator, l2_locator):
    """Normalize artifact locators with specific mount points.

    Args:
        plan: The plan object
        l1_locator: The L1 artifact locator
        l2_locator: The L2 artifact locator

    Returns:
        tuple: (l1_artifacts_locator, l2_artifacts_locator, extra_files)
    """
    (
        l1_artifact_name,
        l1_artifacts_locator,
        l1_mount_point,
    ) = normalize_locator(l1_locator)
    (
        l2_artifact_name,
        l2_artifacts_locator,
        l2_mount_point,
    ) = normalize_locator(l2_locator)

    extra_files = {}
    if l1_mount_point:
        extra_files[l1_mount_point] = plan.get_files_artifact(name=l1_artifact_name)
    if (
        l2_mount_point and l2_mount_point not in extra_files
    ):  # shortcut if both are the same
        extra_files[l2_mount_point] = plan.get_files_artifact(name=l2_artifact_name)

    return l1_artifacts_locator, l2_artifacts_locator, extra_files
