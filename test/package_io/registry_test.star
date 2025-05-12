registry = import_module("/src/package_io/registry.star")

DEFAULT_OP_GETH = "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest"
DEFAULT_OP_NODE = "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop"


def test_registry_default_images(_plan):
    reg = registry.Registry()
    # Should return the default image for OP_GETH
    expect.eq(reg.get(registry.OP_GETH), DEFAULT_OP_GETH)
    # Should return the default image for OP_NODE
    expect.eq(reg.get(registry.OP_NODE), DEFAULT_OP_NODE)


def test_registry_override_images(_plan):
    custom_image = "custom/op-geth:mytag"
    reg = registry.Registry({registry.OP_GETH: custom_image})
    # Should return the overridden image
    expect.eq(reg.get(registry.OP_GETH), custom_image)
    # Should still return default for others
    expect.eq(reg.get(registry.OP_NODE), DEFAULT_OP_NODE)


def test_registry_as_dict_returns_copy(_plan):
    reg = registry.Registry()
    images1 = reg.as_dict()
    images2 = reg.as_dict()
    # Should be equal in value
    expect.eq(images1, images2)
    # But not the same object (modifying one doesn't affect the other)
    images1[registry.OP_GETH] = "modified"
    expect.ne(images1[registry.OP_GETH], images2[registry.OP_GETH])


def test_registry_as_dict_includes_overrides(_plan):
    custom_image = "custom/op-geth:mytag"
    reg = registry.Registry({registry.OP_GETH: custom_image})
    images = reg.as_dict()
    expect.eq(images[registry.OP_GETH], custom_image)
    # Should still include other defaults
    expect.eq(images[registry.OP_NODE], DEFAULT_OP_NODE)
