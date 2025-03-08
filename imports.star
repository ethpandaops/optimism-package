PACKAGES = {
    "ethereum-package": struct(
        id = "github.com/ethpandaops/ethereum-package",
        version  = "4.5.0",
    ),
    "prometheus-package": struct(
        id = "github.com/kurtosis-tech/prometheus-package",
        version  = "f5ce159aec728898e3deb827f6b921f8ecfc527f",
    ),
    "postgres-package": struct(
        id = "github.com/kurtosis-tech/postgres-package",
        version  = "2d363be1bc42524f6b0575cac0bbc0fd194ae173",
    ),
}

def load_module(module_path, package_id=None):
    pkg = struct(id = "", version = None)
    if package_id is not None:
        pkg = PACKAGES[package_id]
    locator = "{0}/{1}".format(pkg.id, module_path)
    if pkg.version is not None:
        locator = "{0}@{1}".format(locator, pkg.version)
    return import_module(locator)
