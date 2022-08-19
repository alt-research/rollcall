# Configuration
export KOVAN_RPC=https://kovan.infura.io/v3/b457369d80df40c68906a224b200bda3
export OPTIMISM_KOVAN_RPC=https://kovan.optimism.io/

# Optimism contract addresses taken from 
# https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts/deployments/kovan
export Proxy__OVM_L1StandardBridge=0x22F24361D548e5FaAfb36d1437839f080363982B
export Proxy__OVM_L1CrossDomainMessenger=0x4361d0F75A0186C05f971c566dC6bEa5957483fD
export L2CrossDomainMessenger=0x4200000000000000000000000000000000000007

export ETH_ADDRESS=0x9774bbb6Ad4B97eC04075627AeED9d2CEC5B30a1
export ETH_PRIVATE_KEY=c59d206e0dd01c7677f76858590cd20561cfd4736aca734a5a11e075b2552f19
export TREASURY_ADDRESS=0xfb8Ba910b52C891f408e7D2AE30B07C947aF72d6
export L2_TOKEN_ADDRESS=0x2EAe58f04d103F9b028b1be06229D85Fad17FfBE
export TEMP_FNAME=/tmp/delme.$$

## deploy L2 Governor
forge create --use solc:0.8.11 SimpleL2Governor \
  --constructor-args $L2_TOKEN_ADDRESS 1 500 0 10 \
  --rpc-url $OPTIMISM_KOVAN_RPC --private-key $ETH_PRIVATE_KEY | tee $TEMP_FNAME

export L2_GOVERNANCE_ADDRESS=`cat $TEMP_FNAME | awk  '/Deployed to:/ {print $3}'`

## deploy Executor on L1
forge create --use solc:0.8.11 Executor \
         --constructor-args $Proxy__OVM_L1CrossDomainMessenger $L2_GOVERNANCE_ADDRESS \
         --rpc-url $KOVAN_RPC --private-key $ETH_PRIVATE_KEY | tee $TEMP_FNAME

export EXECUTOR_ADDRESS=`cat $TEMP_FNAME | awk  '/Deployed to:/ {print $3}'`

cast send $TREASURY_ADDRESS 'setPendingAdmin(address)' $EXECUTOR_ADDRESS \
      --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC --confirmations 1

## test begin

## prepare calldata
TREASURY_CALL=`cast calldata 'acceptPendingAdmin()'`
EXECUTOR_CALL=`cast calldata 'execute(address,bytes)' $TREASURY_ADDRESS $TREASURY_CALL`
BRIDGE_CALL=`cast calldata 'sendMessage(address,bytes,uint32)' $EXECUTOR_ADDRESS $EXECUTOR_CALL 1000000`
# echo $TREASURY_CALL
# echo $EXECUTOR_CALL
# echo
# echo $BRIDGE_CALL

## prepare propose
BRIDGE_CALL_2=`echo $BRIDGE_CALL | cut -c 3-`
L2CrossDomainMessenger_2=`echo $L2CrossDomainMessenger | cut -c 3-`
DESCRIPTION="run acceptPendingAdmin()"
PROPOSAL=`cast calldata 'propose(address[],uint256[],bytes[],string)' \
  '['$L2CrossDomainMessenger_2']' '[0]' '['$BRIDGE_CALL_2']' "$DESCRIPTION"`
# echo
# echo $PROPOSAL
# echo

## send proposal
# cast send $L2_GOVERNANCE_ADDRESS $PROPOSAL --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC --legacy

## get proposal hash
# DESCRIPTION_HASH=`cast keccak "$DESCRIPTION"`
# cast call $L2_GOVERNANCE_ADDRESS 'hashProposal(address[],uint256[],bytes[],bytes32)' \
#          '['$L2CrossDomainMessenger_2']' '[0]' '['$BRIDGE_CALL_2']' \
#           $DESCRIPTION_HASH\
#          --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC
# export PROPOSAL_ID=15031995ff33ca69b80c4f3ac7b09f420e1db6456547d8eb864a4ef4f02fe3b2

# vote
# VOTE=1
# cast send $L2_GOVERNANCE_ADDRESS 'castVote(uint256,uint8)' $PROPOSAL_ID $VOTE --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC --chain optimism-kovan --confirmations 1
# cast call $L2_GOVERNANCE_ADDRESS 'proposalDeadline(uint256 proposalId)' $PROPOSAL_ID --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC 
# cast call $L2_GOVERNANCE_ADDRESS 'state(uint256 proposalId)' $PROPOSAL_ID --rpc-url $OPTIMISM_KOVAN_RPC 
