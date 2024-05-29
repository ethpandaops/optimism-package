ethereum_package = import_module(
    "github.com/kurtosis-tech/ethereum-package/main.star@3.0.0"
)

def run(plan, args):
    plan.print("here")
    ethereum_package.run(plan, args)