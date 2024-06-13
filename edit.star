optimism = import_module("github.com/tedim52/optimism-package/main.star")

def run(plan, args):
    optimism.run(plan, {
        "l2s": [
            {
            "participants": [
                {
                "el_type": "op-geth", 
                "el_image": "jinmel/op-geth:preconf1"
                }
            ], 
            "additional_services": [
                "blockscout"
            ], 
            "name": "rollup_two", 
            "network_params": {
                "network_id": "3151909", 
                "preset": "minimal"
            }
            }, 
            {
            "participants": [
                {
                "el_type": "op-geth", 
                "el_image": "jinmel/op-geth:preconf1"
                }
            ], 
            "additional_services": [
                "blockscout"
            ], 
            "network_params": {
                "network_id": "3151910", 
                "preset": "minimal"
            }, 
            "name": "rollup_one"
            }
        ], 
        "l1": {
            "participants": [
            {
                "el_type": "geth"
            }
            ], 
            "network_params": {
            "preset": "minimal"
            }
        }
    })

    # plan.set_service(name="op-geth...", config = ServiceConfig(image=ImageBuildSpec(
    #     build_context=".",
    #     name="jinmel/op-geth:preconfig1"
    # )))
