# Deploy MakinaX

This README outlines the steps to deploy the MakinaX contracts and to create MakinaX module instances.

## Environment setup

- Copy `.env.example` to `.env` and fill in the required RPC URLs, Etherscan API URLs, and API keys.
- Build the project as described in the [root README](../README.md). `yarn build:ir` is required, as `DeployMakinaX` deploys `WeirollVM` from the IR build output.
- Some networks are preconfigured in `foundry.toml` and only require the corresponding environment variables. More networks can be added following similar configuration.
- Notation used in the commands:
  - `<wallet-options>` - the flags specifying the deployer wallet, see the [Foundry docs](https://getfoundry.sh/forge/reference/script/)
  - `<network-alias>` - must match a network name declared in `foundry.toml`

## Infrastructure Deployment

Set the `INFRA_INPUT_FILENAME` and `INFRA_OUTPUT_FILENAME` values in your `.env` file to define the input and output JSON filenames, respectively. For example, for a deployment on Ethereum Mainnet, both of these files can be named `Mainnet.json`.

1. Copy `script/deployments/inputs/makina-x-infra/TEMPLATE.json` to `script/deployments/inputs/makina-x-infra/{INFRA_INPUT_FILENAME}` and fill in the required variables.

   The `superAdminRoleGrant` entry sets the account granted the `ADMIN_ROLE` in the deployed `AccessManager`, with its execution delay. The `otherRoleGrants` array declares additional role grants, one entry per `roleId`/`account`/`executionDelay` triple.

   The `bridgesTargets` array declares the bridge encoders to deploy, one entry per bridge. Each entry sets a `bridgeId` and the fields required by that bridge:
   - `1` (Across V4) - requires `acrossV4SpokePool`
   - `2` (LayerZero V2) - no additional field
   - `3` (CCTP V2) - requires `cctpV2TokenMessenger`

2. Run the following command to initiate the deployment of infrastructure contracts, as well as registry and Access Management setup. This will generate an output file at `script/deployments/outputs/makina-x-infra/{INFRA_OUTPUT_FILENAME}` containing the deployed contract addresses.

```
forge script script/deployments/DeployMakinaX.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

Note: This script performs deterministic deployment based on the deployer wallet address via the [CreateX Factory contract](https://github.com/pcaversaccio/createx).

3. Run the following command to configure the bridge encoders deployed at step 2. The script detects the connected chain via its chain id (which must be one of the supported chains listed in the script) and registers the CCTP V2 domains and LayerZero V2 endpoint ids of the other supported chains. This script needs to be run from an address holding the `INFRA_CONFIG_ROLE` in the `AccessManager` deployed at step 2.

```
forge script script/setup/SetupBridgeEncoders.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast -vvvv
```

A deployment is either staging, where the deployer keeps sole control of the `AccessManager`, or production, where control is handed to the configured accounts at step 2. Each flavor has one optional `.env` setting.

### Staging: skip the AccessManager setup (step 2)

Set `SKIP_AM_SETUP=true` to skip the `AccessManager` setup at step 2 (function roles and role grants). The deployer keeps the `ADMIN_ROLE` and runs step 3 and the module creation scripts directly. Leave unset (or `false`) for production.

### Production: view mode (step 3)

In production, step 3 is run from an account holding the `INFRA_CONFIG_ROLE`. Set `VIEW_MODE=true` to log each call's target (bridge encoder) and calldata for the account to submit, instead of broadcasting. The target chain's `--rpc-url` is still required, as the script selects the chain via its chain id. Leave the variable unset (or `false`) to broadcast.

## Module Instances

Set the `INFRA_OUTPUT_FILENAME` (from the infrastructure deployment step, used to read the `ModuleFactory` address), `MODULE_INPUT_FILENAME` and `MODULE_OUTPUT_FILENAME` values in your `.env` file.

### View mode

Set `VIEW_MODE=true` in your `.env` to run either module creation script below without broadcasting: it logs the `ModuleFactory` target address and the calldata it would send, then exits without sending a transaction or writing an output file. Leave the variable unset (or `false`) for normal broadcasting.

### Standard module instance

Deployed through `ModuleFactory.createModule`, which is a permissioned call. The broadcasting address must have the `STRATEGY_DEPLOYMENT_ROLE` in the `AccessManager`.

1. Copy `script/deployments/inputs/makina-x-modules/TEMPLATE.json` to `script/deployments/inputs/makina-x-modules/{MODULE_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/makina-x-modules/{MODULE_OUTPUT_FILENAME}` containing the deployed module address.

```
forge script script/deployments/CreateModule.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast -vvvv
```

### Free module instance

Deployed through `ModuleFactory.createModuleFree`, which is callable by anyone while free deployment is enabled on the `ModuleFactory`. The service parameters (provider and swap fee rate) are enforced by the factory, so the input file omits them.

1. Copy `script/deployments/inputs/makina-x-modules/TEMPLATE-Free.json` to `script/deployments/inputs/makina-x-modules/{MODULE_INPUT_FILENAME}` and fill in the required variables.
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/makina-x-modules/{MODULE_OUTPUT_FILENAME}` containing the deployed module address.

```
forge script script/deployments/CreateModuleFree.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast -vvvv
```
