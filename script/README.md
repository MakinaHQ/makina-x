# Deploy MakinaX

This README outlines the steps to deploy the MakinaX contracts and to create MakinaX module instances.

## Environment setup

- Copy `.env.example` to `.env` and fill in the required RPC URLs, Etherscan API URLs, and API keys.
- Some networks are preconfigured in `foundry.toml` and only require the corresponding environment variables. More networks can be added following similar configuration.
- The commands below use a foundry keystore to specify the deployment wallet (`--account <keystore-name>`). For other options, refer to the [Foundry docs](https://getfoundry.sh/forge/reference/script/).
- Notation used in the commands:
  - `<keystore-name>` - the name of a Foundry keystore containing the deployer's private key
  - `<network-alias>` - must match a network name declared in `foundry.toml`

## Infrastructure Deployment

Set the `INFRA_INPUT_FILENAME` and `INFRA_OUTPUT_FILENAME` values in your `.env` file to define the input and output JSON filenames, respectively. For example, for a deployment on Ethereum Mainnet, both of these files can be named `Mainnet.json`.

### View mode

Steps 3 to 5 below are typically run from a multisig holding the required role in the `AccessManager` provided at step 1 (`ADMIN_ROLE` for steps 3 and 5, `INFRA_CONFIG_ROLE` for step 4). Set `VIEW_MODE=true` in your `.env` to run any of these scripts without broadcasting: it logs the target address (`AccessManager` for step 3, `MakinaXRegistry` for step 4, the bridge encoders for step 5) and the calldata of each call it would send, then exits without sending a transaction. Leave the variable unset (or `false`) for normal broadcasting.

### Shared contracts

1. Copy `script/deployments/inputs/makina-x-infra/TEMPLATE.json` to `script/deployments/inputs/makina-x-infra/{INFRA_INPUT_FILENAME}` and fill in the required variables.

   The `bridgesTargets` array declares the bridge encoders to deploy, one entry per bridge. Each entry sets a `bridgeId` and the fields required by that bridge:
   - `1` (Across V4) - requires `acrossV4SpokePool`
   - `2` (LayerZero V2) - no additional field
   - `3` (CCTP V2) - requires `cctpV2TokenMessenger`

2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/makina-x-infra/{INFRA_OUTPUT_FILENAME}` containing the deployed contract addresses (registry, module factory, module implementation, flash loan module, and bridge encoders).

```
forge script script/deployments/DeployMakinaX.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast --verify -vvvv
```

Note: This script performs deterministic deployment based on the deployer wallet address via the [CreateX Factory contract](https://github.com/pcaversaccio/createx).

3. Run the following command to run contracts AccessManager setup. This script needs to be run from an address that has the `ADMIN_ROLE` in the `AccessManager` provided at step 1.

```
forge script script/deployments/SetupMakinaXAM.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast -vvvv
```

4. Run the following command to run Registry contract setup. This sets the registry component addresses and registers the bridge encoders deployed at step 2. This script needs to be run from an address authorized in the `AccessManager` provided at step 1.

```
forge script script/deployments/SetupMakinaXRegistry.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast -vvvv
```

5. Run the chain-specific script under `script/deployments/bridge-setup/` to configure the bridge encoders deployed at step 2. It registers the CCTP V2 domains and LayerZero V2 endpoint ids of other supported chains. This script needs to be run from an address authorized in the `AccessManager` provided at step 1. For example, on Ethereum Mainnet:

```
forge script script/deployments/bridge-setup/SetupBridgeEncodersEthereum.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast -vvvv
```

## Module Instances

Set the `INFRA_OUTPUT_FILENAME` (from the infrastructure deployment step, used to read the `ModuleFactory` address), `MODULE_INPUT_FILENAME` and `MODULE_OUTPUT_FILENAME` values in your `.env` file.

### View mode

Set `VIEW_MODE=true` in your `.env` to run either module creation script below without broadcasting: it logs the `ModuleFactory` target address and the calldata it would send, then exits without sending a transaction or writing an output file. Leave the variable unset (or `false`) for normal broadcasting.

### Standard module instance

Deployed through `ModuleFactory.createModule`, which is a permissioned call. The broadcasting address must have the `STRATEGY_DEPLOYMENT_ROLE` in the `AccessManager`.

1. Copy `script/deployments/inputs/makina-x-modules/TEMPLATE.json` to `script/deployments/inputs/makina-x-modules/{MODULE_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/makina-x-modules/{MODULE_OUTPUT_FILENAME}` containing the deployed module address.

```
forge script script/deployments/CreateModule.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast -vvvv
```

### Free module instance

Deployed through `ModuleFactory.createModuleFree`, which is callable by anyone while free deployment is enabled on the `ModuleFactory`. The service parameters (provider and swap fee rate) are enforced by the factory, so the input file omits them.

1. Copy `script/deployments/inputs/makina-x-modules/TEMPLATE-Free.json` to `script/deployments/inputs/makina-x-modules/{MODULE_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/makina-x-modules/{MODULE_OUTPUT_FILENAME}` containing the deployed module address.

```
forge script script/deployments/CreateModuleFree.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast -vvvv
```
