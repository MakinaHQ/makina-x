# MakinaLite Access Control

MakinaLite uses two distinct access control systems:

- **Module-level roles** (Safe, Provider, Operator, Guardian) govern the `MakinaLiteModule` and are managed directly through simple role mappings.
- **Infrastructure roles** govern the `MakinaLiteRegistry`, `ModuleFactory`, and Bridge Encoder contracts through [OpenZeppelin AccessManager](https://docs.openzeppelin.com/contracts/5.x/api/access#AccessManager).

## Module-Level Roles

### Safe

The Safe is the ultimate owner of the module and all managed assets. It has exclusive authority over configuration and risk parameters.

- Can add and remove operators.
- Can add and remove guardians.
- Can set the operating mode.
- Can set the allowed instruction Merkle root.
- Can set the accounting currency.
- Can set, update and clear price feed routes.
- Can set price feed staleness thresholds.
- Can set the maximum allowed value loss for position increases.
- Can set the maximum allowed value loss for position decreases.
- Can set the cooldown duration for position management instructions.
- Can set the maximum allowed value loss for token swaps.
- Can set the cooldown duration for token swaps.
- Can set swapper approval and execution targets.
- Can set the maximum allowed value loss for bridge transfers.
- Can set the cooldown duration for bridge transfers.
- Can add and remove whitelisted bridge transfer recipients.
- Can sweep ERC20 tokens held by the module back to the Safe.
- Can sweep native tokens held by the module back to the Safe.

### Provider

The provider is the protocol's service account. It manages service-level parameters and can suspend module operations.

- Can set the swap fee rate.
- Can suspend and unsuspend the module.
- Can transfer the provider role to a new address.

### Operators

Operators are authorized to execute strategy operations through the module. All operator actions require the module to be operational (not paused and not suspended).

- Can account for one or multiple positions.
- Can manage (open, modify, close) one or multiple positions.
- Can execute token swaps.
- Can harvest external rewards and swap them.
- Can send outgoing bridge transfers.

### Guardians

Guardians serve as emergency contacts that can halt module operations. The Safe is always a guardian and cannot be removed from this role.

- Can pause and unpause the module.

## Infrastructure Roles

The following contracts use OpenZeppelin's `AccessManagedUpgradeable` with the `restricted` modifier. Function-level permissions are configured by the associated `AccessManager` instance. Roles used by MakinaLite infrastructure contracts are a subset of those used in Makina Core, and are assigned at deployment.

### MakinaLiteRegistry

- `INFRA_CONFIG_ROLE` (roleId `1`)
  - Can set the address of ModuleFactory.
  - Can set the address of the module implementation.
  - Can set the address of the fee collector.
  - Can set the address of the FlashLoanModule.
  - Can set bridge encoder addresses.

- `INFRA_UPGRADE_ROLE` (roleId `6`)
  - Can upgrade implementation via associated ProxyAdmin.

### ModuleFactory

- `STRATEGY_DEPLOYMENT_ROLE` (roleId `2`)
  - Can deploy new MakinaLiteModule clones.

- `INFRA_UPGRADE_ROLE` (roleId `6`)
  - Can upgrade implementation via associated ProxyAdmin.

### AcrossV4BridgeEncoder

- `INFRA_CONFIG_ROLE` (roleId `1`)
  - Can add and remove token routes (input token to output token mappings per chain).

- `INFRA_UPGRADE_ROLE` (roleId `6`)
  - Can upgrade implementation via associated ProxyAdmin.

### CctpV2BridgeEncoder

- `INFRA_CONFIG_ROLE` (roleId `1`)
  - Can set mappings of EVM chain ID to CCTP domain.

- `INFRA_UPGRADE_ROLE` (roleId `6`)
  - Can upgrade implementation via associated ProxyAdmin.

### LayerZeroV2BridgeEncoder

- `INFRA_CONFIG_ROLE` (roleId `1`)
  - Can set mappings of EVM chain ID to LZ endpoint ID.
  - Can register and unregister OFT contracts.

- `INFRA_UPGRADE_ROLE` (roleId `6`)
  - Can upgrade implementation via associated ProxyAdmin.

## Operational States

The module can restrict its functionality through two independent toggles (`Paused`, `Suspended`) and the operating mode (`OPEN`, `FENCED`, `WALLED`), where `OPEN` enforces no additional restrictions:

| State                       | Set by   | Effect                                                                                                                                                                                              |
| --------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Paused**                  | Guardian | Blocks all operator actions.                                                                                                                                                                        |
| **Suspended**               | Provider | Blocks all operator actions.                                                                                                                                                                        |
| **FENCED** (operating mode) | Safe     | Enforces additional safety checks on swaps and bridge transfers: value loss limits, cooldowns, bridge recipient whitelisting, and OFT/route registration checks. Position management is unaffected. |
| **WALLED** (operating mode) | Safe     | Enforces all `FENCED` checks, plus position management restrictions: mandatory accounting, value preservation checks, and instruction cooldowns.                                                    |
