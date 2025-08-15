# Taken from https://github.com/ethereum/hive and modified to support more cases for Ethereum / OP / Taiko networks

# Usage: cat genesis.json | jq --from-file gen2spec.jq > chainspec.json

# Removes all empty keys and values in input.
def remove_empty:
  . | walk(
    if type == "object" then
      with_entries(
        select(
          .value != null and
          .value != "" and
          .value != [] and
          .key != null and
          .key != ""
        )
      )
    else .
    end
  )
;

# Converts number to hex, from https://rosettacode.org/wiki/Non-decimal_radices/Convert#jq
def int_to_hex:
  def stream:
    recurse(if . > 0 then ./16|floor else empty end) | . % 16 ;
  if . == 0 then "0x0"
  else "0x" + ([stream] | reverse | .[1:] | map(if .<10 then 48+. else 87+. end) | implode)
  end
;

# Converts decimal number in string to hex.
def to_hex:
  if . != null and type == "number" then .|int_to_hex else
    if . != null and startswith("0x") then . else
      if (. != null and . != "") then .|tonumber|int_to_hex else . end
    end
  end
;

# Zero-pads hex string.
def infix_zeros_to_length(s;l):
  if . != null then
    (.[0:s])+("0"*(l-(.|length)))+(.[s:l])
  else .
  end
;

# This gives the consensus engine definition for the ethash engine.
def ethash:
  {
    "Ethash": {}
  }
;

# This gives the consensus engine definition for the op engine.
def optimism:
  {
    "Optimism": {
        "params": {
          "bedrockBlockNumber": .config.bedrockBlock|to_hex,
          "regolithTimestamp": .config.regolithTime|to_hex,
          "canyonTimestamp": .config.canyonTime|to_hex,
          "ecotoneTimestamp": .config.ecotoneTime|to_hex,
          "fjordTimestamp": .config.fjordTime|to_hex,
          "graniteTimestamp": .config.graniteTime|to_hex,
          "holoceneTimestamp": .config.holoceneTime|to_hex,
          "isthmusTimestamp": .config.isthmusTime|to_hex,
          "jovianTimestamp": .config.jovianTime|to_hex,
          "interopTimestamp": .config.interopTime|to_hex,
          "l1FeeRecipient": "0x420000000000000000000000000000000000001A",
          "l1BlockAddress": "0x4200000000000000000000000000000000000015",
          "canyonBaseFeeChangeDenominator": .config.optimism.eip1559DenominatorCanyon,
          "create2DeployerAddress": "0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2",
          "create2DeployerCode": "6080604052600436106100435760003560e01c8063076c37b21461004f578063481286e61461007157806356299481146100ba57806366cfa057146100da57600080fd5b3661004a57005b600080fd5b34801561005b57600080fd5b5061006f61006a366004610327565b6100fa565b005b34801561007d57600080fd5b5061009161008c366004610327565b61014a565b60405173ffffffffffffffffffffffffffffffffffffffff909116815260200160405180910390f35b3480156100c657600080fd5b506100916100d5366004610349565b61015d565b3480156100e657600080fd5b5061006f6100f53660046103ca565b610172565b61014582826040518060200161010f9061031a565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe082820381018352601f90910116604052610183565b505050565b600061015683836102e7565b9392505050565b600061016a8484846102f0565b949350505050565b61017d838383610183565b50505050565b6000834710156101f4576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f437265617465323a20696e73756666696369656e742062616c616e636500000060448201526064015b60405180910390fd5b815160000361025f576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f437265617465323a2062797465636f6465206c656e677468206973207a65726f60448201526064016101eb565b8282516020840186f5905073ffffffffffffffffffffffffffffffffffffffff8116610156576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601960248201527f437265617465323a204661696c6564206f6e206465706c6f790000000000000060448201526064016101eb565b60006101568383305b6000604051836040820152846020820152828152600b8101905060ff815360559020949350505050565b61014e806104ad83390190565b6000806040838503121561033a57600080fd5b50508035926020909101359150565b60008060006060848603121561035e57600080fd5b8335925060208401359150604084013573ffffffffffffffffffffffffffffffffffffffff8116811461039057600080fd5b809150509250925092565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b6000806000606084860312156103df57600080fd5b8335925060208401359150604084013567ffffffffffffffff8082111561040557600080fd5b818601915086601f83011261041957600080fd5b81358181111561042b5761042b61039b565b604051601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0908116603f011681019083821181831017156104715761047161039b565b8160405282815289602084870101111561048a57600080fd5b826020860160208301376000602084830101528095505050505050925092509256fe608060405234801561001057600080fd5b5061012e806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c8063249cb3fa14602d575b600080fd5b603c603836600460b1565b604e565b60405190815260200160405180910390f35b60008281526020818152604080832073ffffffffffffffffffffffffffffffffffffffff8516845290915281205460ff16608857600060aa565b7fa2ef4600d742022d532d4747cb3547474667d6f13804902513b2ec01c848f4b45b9392505050565b6000806040838503121560c357600080fd5b82359150602083013573ffffffffffffffffffffffffffffffffffffffff8116811460ed57600080fd5b80915050925092905056fea26469706673582212205ffd4e6cede7d06a5daf93d48d0541fc68189eeb16608c1999a82063b666eb1164736f6c63430008130033a2646970667358221220fdc4a0fe96e3b21c108ca155438d37c9143fb01278a3c1d274948bad89c564ba64736f6c63430008130033",
        }
    }
  }
;

def taiko:
  {
    "Taiko": {
      "ontakeTransition": .config.ontakeBlock|to_hex,
      "pacayaTransition": .config.pacayaBlock|to_hex,
      "useSurgeGasPriceOracle": .config.useSurgeGasPriceOracle,
      "taikoL2Address": "0x\(.config.chainId)0000000000000000000000000000010001"
    }
  }
;

def clique:
  {
    "clique": {
        "params": {
          "period": .config.clique.period,
          "epoch": .config.clique.epoch,
        }
    }
  }
;

{
  "version": "1",
  "engine": (if .config.optimism != null then optimism elif .config.taiko != null then taiko elif .config.clique != null then clique else ethash end),
  "params": ({
    # Tangerine Whistle
    "eip150Transition": "0x0",

    # Spurious Dragon
    "eip155Transition": "0x0",
    "eip160Transition": "0x0",
    "eip161abcTransition": "0x0",
    "eip161dTransition": "0x0",
    "maxCodeSize": "0x6000",
    "maxCodeSizeTransition": "0x0",
    "maximumExtraDataSize": "0x20",

    # Byzantium
    "eip140Transition": .config.byzantiumBlock|to_hex,
    "eip211Transition": .config.byzantiumBlock|to_hex,
    "eip214Transition": .config.byzantiumBlock|to_hex,
    "eip658Transition": .config.byzantiumBlock|to_hex,

    # Constantinople
    "eip145Transition": .config.constantinopleBlock|to_hex,
    "eip1014Transition": .config.constantinopleBlock|to_hex,
    "eip1052Transition": .config.constantinopleBlock|to_hex,

    # Petersburg
    "eip1283Transition": .config.petersburgBlock|to_hex,
    "eip1283DisableTransition": .config.petersburgBlock|to_hex,

    # Istanbul
    "eip152Transition": .config.istanbulBlock|to_hex,
    "eip1108Transition": .config.istanbulBlock|to_hex,
    "eip1344Transition": .config.istanbulBlock|to_hex,
    "eip1884Transition": .config.istanbulBlock|to_hex,
    "eip2028Transition": .config.istanbulBlock|to_hex,
    "eip2200Transition": .config.istanbulBlock|to_hex,

    # Berlin
    "eip2565Transition": .config.berlinBlock|to_hex,
    "eip2718Transition": .config.berlinBlock|to_hex,
    "eip2929Transition": .config.berlinBlock|to_hex,
    "eip2930Transition": .config.berlinBlock|to_hex,

    # London
    "eip1559Transition": .config.londonBlock|to_hex,
    "eip1559ElasticityMultiplier": .config.optimism.eip1559Elasticity|to_hex,
    "eip1559BaseFeeMaxChangeDenominator": .config.optimism.eip1559Denominator|to_hex,
    "eip3198Transition": .config.londonBlock|to_hex,
    "eip3238Transition": .config.londonBlock|to_hex,
    "eip3529Transition": .config.londonBlock|to_hex,
    "eip3541Transition": .config.londonBlock|to_hex,

    # Merge
    "mergeForkIdTransition": .config.mergeForkBlock|to_hex,

    # Shanghai
    "eip3651TransitionTimestamp": .config.shanghaiTime|to_hex,
    "eip3855TransitionTimestamp": .config.shanghaiTime|to_hex,
    "eip3860TransitionTimestamp": .config.shanghaiTime|to_hex,
    "eip4895TransitionTimestamp": .config.shanghaiTime|to_hex,

    # Cancun
    "eip1153TransitionTimestamp": .config.cancunTime|to_hex,
    "eip4788TransitionTimestamp": .config.cancunTime|to_hex,
    "eip4844TransitionTimestamp": .config.cancunTime|to_hex,
    "eip5656TransitionTimestamp": .config.cancunTime|to_hex,
    "eip6780TransitionTimestamp": .config.cancunTime|to_hex,

    # OP forks
    "rip7212TransitionTimestamp": .config.fjordTime|to_hex,
    "opGraniteTransitionTimestamp": .config.graniteTime|to_hex,
    "opHoloceneTransitionTimestamp": .config.holoceneTime|to_hex,
    "opIsthmusTransitionTimestamp": .config.isthmusTime|to_hex,

    # Prague
    "eip2537TransitionTimestamp": (.config.isthmusTime // .config.pragueTime)|to_hex,
    "eip2935TransitionTimestamp": (.config.isthmusTime // .config.pragueTime)|to_hex,
    "eip6110TransitionTimestamp": (.config.isthmusTime // .config.pragueTime)|to_hex,
    "eip7623TransitionTimestamp": (.config.isthmusTime // .config.pragueTime)|to_hex,
    "eip7702TransitionTimestamp": (.config.isthmusTime // .config.pragueTime)|to_hex,
  } + if .config.optimism != null then { 
    "eip7685TransitionTimestamp": .config.isthmusTime|to_hex,
  } else {
    "eip7002TransitionTimestamp": .config.pragueTime|to_hex,
    "eip7251TransitionTimestamp": .config.pragueTime|to_hex,
  } end + {
    "depositContractAddress": .config.depositContractAddress,

    "blobSchedule" : (if .config.blobSchedule then ((
      (.config as $c | ["cancun", "prague", "osaka", "amsterdam", "bpo1", "bpo2", "bpo3", "bpo4", "bpo5"]
      | map({ timestamp: $c[. + "Time"] } + $c.blobSchedule[.]))
    )
    | reverse
    | unique_by(.timestamp)
    | map(select(length > 1))
    ) else null end),

    # Osaka
    "eip7594TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7823TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7825TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7883TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7918TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7934TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7939TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7951TransitionTimestamp": .config.osakaTime|to_hex,

    # Fee collector
    "feeCollector":  (if .config.optimism != null then "0x4200000000000000000000000000000000000019" elif .config.taiko != null then .config.feeCollector // "0x\(.config.chainId)0000000000000000000000000000010001" else null end),
    "eip1559FeeCollectorTransition": (if .config.optimism != null or .config.taiko != null then .config.londonBlock|to_hex else null end),

    # Other chain parameters
    "networkID": .config.chainId|to_hex,
    "chainID": .config.chainId|to_hex,

    "terminalTotalDifficulty": (if .config.taiko != null then "0x0" else .config.terminalTotalDifficulty|to_hex end),

    "eip1559BaseFeeMinValueTransition": .config.ontakeBlock|to_hex,
    "eip1559BaseFeeMinValue": (if .config.ontakeBlock then "0x86ff51" else null end),
  }),
  "genesis": {
    "seal": {
      "ethereum":{
         "nonce": .nonce|infix_zeros_to_length(2;18),
         "mixHash": .mixHash,
      },
    },
    "difficulty": (if .config.taiko != null then "0x0" else .difficulty|to_hex end),
    "author": .coinbase,
    "timestamp": .timestamp,
    "parentHash": .parentHash,
    "extraData": .extraData,
    "gasLimit": .gasLimit,
    "baseFeePerGas": .baseFeePerGas,
    "blobGasUsed": .blobGasUsed,
    "excessBlobGas": .excessBlobGas,
    "parentBeaconBlockRoot": .parentBeaconBlockRoot,
  },
  "accounts": ((.alloc|with_entries(.key|=(if startswith("0x") then . else "0x" + . end)))),
}|remove_empty
