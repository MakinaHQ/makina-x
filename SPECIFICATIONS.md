# MakinaLite Specifications

## Protocol

### MakinaLiteModule

The `MakinaLiteModule` contract is the core component of MakinaLite. It is deployed as a [Safe module](https://docs.safe.global/advanced/smart-account-modules), enabling it to execute transactions on behalf of the Safe without requiring multisig confirmations for each action. The module composes several components: position management, token swaps, cross-chain bridging, and price oracles.

Each module is deployed as a minimal clone via the `ModuleFactory` and initialized with configuration parameters including the Safe address, provider address, allowed instruction Merkle root, loss limits, and swap fee rate.

#### Standard Operator Actions

- Can account for one or multiple positions at a time.
- Can open, manage and close one or multiple positions at a time.
- Can harvest external rewards and swap them into desired tokens.
- Can execute token swaps through configured DEX aggregators.
- Can send outgoing bridge transfers to other chains.

### Position Management

Position management is handled by the `WeirollComponent`, which leverages the [Weiroll](https://github.com/EnsoBuild/enso-weiroll) command-chaining framework to execute DeFi operations through the Safe via delegatecall.

#### Instructions

A set of instructions can be pre-approved and registered in a Merkle tree, whose root is stored in the module and used to verify authorization proofs. Each instruction includes a bitmap that determines which state parameters are fixed (included in the Merkle leaf) and which are variable (excluded from the hash). This enables a single pre-approved instruction to be executed with different parameters for designated slots.

Instructions can be of four different types:

- **MANAGEMENT**: Modifies the size of a position. A `MANAGEMENT` instruction is always paired with an `ACCOUNTING` instruction to account for the changes it introduces. In lockdown mode, the accounting instruction is mandatory.
- **ACCOUNTING**: Calculates the current value of a position using the affected tokens' balances and the oracle registry.
- **HARVEST**: Collects rewards earned by open positions from external protocols.
- **FLASHLOAN_MANAGEMENT**: Modifies the size of a position in the context of a flash loan, as part of an outer `MANAGEMENT` instruction. A `FLASHLOAN_MANAGEMENT` instruction is always associated with a `MANAGEMENT` instruction and can only be executed in its scope.

Each `Instruction` object includes an `affectedTokens` list. For `MANAGEMENT` instructions, this list must include all tokens spent by the instruction. For `ACCOUNTING` instructions, this list must include all tokens in which the position value is expressed. For `HARVEST` and `FLASHLOAN_MANAGEMENT` instructions, this list is ignored.

#### Position Value Loss Checks

When lockdown mode is enabled, position management operations enforce value loss limits. After each management instruction, the module compares the position value change against the change in affected token balances held by the Safe:

- For position increases: the position value gained must be within `maxPositionIncreaseLossBps` of the tokens spent.
- For position decreases: the tokens received must be within `maxPositionDecreaseLossBps` of the position value lost.

#### Assumptions

The protocol relies on specific assumptions on the instructions. Some are always required for correct behavior, while others are only relevant in lockdown mode but remain best practice regardless.

- **ACCOUNTING**:
  - They must not introduce changes in position states or token balances.
  - Their output must be resistant to manipulation by third parties (e.g., via sandwich attacks).
  - The `affectedTokens` list must include exactly all tokens in which the position size is expressed.
  - Their output state must start with an ordered list of amounts (one amount per slot) matching the order of `affectedTokens`, followed by an end-of-args flag.
- **MANAGEMENT**:
  - The `affectedTokens` list must include exactly all tokens spent by the instruction.
- **HARVEST**:
  - They should be restricted to receive-only operations and should not spend any tokens that are initially held by the Safe.
- **FLASHLOAN_MANAGEMENT**:
  - They must not result in token balance changes for tokens that are not in the `affectedTokens` list of the associated `MANAGEMENT` instruction.

### SwapModule

The `SwapComponent` enables the module to execute token swaps through external DEX protocols using unverified calldata. For each registered swapper, an approval target and an execution target are configured. The module pulls funds from the Safe, approves the approval target, executes the swap calldata on the execution target, revokes the approval, and returns the output tokens to the Safe.

When lockdown mode is enabled, swap operations enforce a value loss limit (`maxSwapLossBps`) by comparing the output value against the input value using oracle prices.

#### Fees

A configurable swap fee rate, set by the provider, is applied to every swap output. Fees are transferred to the fee collector address stored in the `MakinaLiteRegistry`. The fee rate is expressed as a fraction of `1e18` (i.e., `1e18` = 100%).

### Oracle Registry

The `OracleRegistry` component prices tokens in a reference currency (e.g. USD) by aggregating price feeds that implement Chainlink's `AggregatorV2V3Interface`, using either a single feed or a two-feed path. For each feed, a staleness threshold is configured.

The oracle is used for:

- Position value calculations during accounting.
- Value loss enforcement during swaps and position management in lockdown mode.

#### Accounting Currency

By default, position values are expressed in the reference currency (address(0)). An optional accounting currency can be set per module, in which case position values are expressed in that token using the oracle's cross-token pricing.

### Liquidity Bridging

The `BridgeComponent` enables cross-chain token transfers through a modular bridge encoder system. The module supports multiple bridge protocols via a set of `BridgeEncoder` contracts that each encode the appropriate calldata for a given external bridge.

For each bridge transfer, the module pulls the input token from the Safe and delegates the calldata encoding to the corresponding bridge encoder registered in the `MakinaLiteRegistry` for the given bridge ID.

#### Lockdown Mode Restrictions

When lockdown mode is enabled, bridge transfers enforce:

- **Recipient whitelisting**: The recipient on the destination chain must be whitelisted for that specific chain ID.
- **Value loss limits**: The minimum output amount must be within `maxBridgeLossBps` of the input amount.
- **Route/OFT registration checks**: Bridge-specific checks are enforced depending on the bridge protocol (e.g. route registration for Across V4, OFT registration for LayerZero V2).

#### Supported Bridge Protocols

**Across V4** (`AcrossV4BridgeEncoder`): Routes tokens through the Across V4 SpokePool using `depositV3Now`. Supports configurable token routes (input token to output token per destination chain). In lockdown mode, only registered routes are allowed.

**Circle CCTP V2** (`CctpV2BridgeEncoder`): Bridges tokens through Circle's Cross-Chain Transfer Protocol using `depositForBurnWithHook`. Maintains a mapping of EVM chain IDs to CCTP domains.

**LayerZero V2** (`LayerZeroV2BridgeEncoder`): Bridges tokens through LayerZero's OFT (Omnichain Fungible Token) standard. Maintains mappings of EVM chain IDs to LayerZero endpoint IDs and a registry of allowed OFT contracts. In lockdown mode, only registered OFTs are allowed.

### Flash Loans

The `FlashLoanModule` contract handles flash loan requests via [Morpho](https://morpho.org/). Flash loans are used in the context of `FLASHLOAN_MANAGEMENT` instructions to leverage flash-loaned funds during position management.

The flow operates as follows:

1. The Safe calls `requestFlashLoan` on the `FlashLoanModule`, specifying the taker module, token, amount, and the `FLASHLOAN_MANAGEMENT` instruction.
2. The `FlashLoanModule` requests the flash loan from Morpho.
3. Morpho calls back `onMorphoFlashLoan` on the `FlashLoanModule`.
4. The `FlashLoanModule` transfers the flash-loaned funds to the Safe and delegates execution to the taker module's `manageFlashLoan` function.
5. The taker module executes the `FLASHLOAN_MANAGEMENT` instruction via the Safe.
6. The taker module instructs the Safe to transfer the repayment amount to the `FlashLoanModule`, which repays Morpho.

The `FlashLoanModule` validates that the taker is a module deployed by the `ModuleFactory` and that the caller is the taker's Safe. Reentrancy is prevented via transient storage flags.

### MakinaLiteRegistry

The `MakinaLiteRegistry` contract stores addresses of shared protocol components. It is a single upgradeable instance that all modules reference for:

- The `ModuleFactory` address.
- The module implementation address (used by the factory for cloning).
- The fee collector address (receives swap fees).
- The `FlashLoanModule` address.
- Bridge encoder addresses (mapped by bridge ID).

### ModuleFactory

The `ModuleFactory` deploys new `MakinaLiteModule` instances as [ERC-1167](https://eips.ethereum.org/EIPS/eip-1167) minimal clones. Each clone is initialized with the provided parameters and tracked by the factory.

### Access Control

The MakinaLite protocol uses two access control systems:

**Module-level roles** — The `MakinaLiteGovernable` contract defines four roles: Safe, Provider, Operator, and Guardian. These are implemented as simple address mappings and modifiers. The Safe is the sole authority over configuration. Operators execute strategy actions. Guardians can pause the module. The provider manages service-level parameters and can suspend operations. See [PERMISSIONS.md](PERMISSIONS.md) for the full list of permissions.

**Infrastructure roles** — The `MakinaLiteRegistry`, `ModuleFactory`, and Bridge Encoder contracts implement [OpenZeppelin AccessManagedUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/access/manager/AccessManagedUpgradeable.sol), delegating authorization to an external `AccessManager` instance. See [PERMISSIONS.md](PERMISSIONS.md) for the full list of permissions.

Roles used by MakinaLite infrastructure contracts are a subset of those used in Makina Core contracts, and are defined as follows:

- `ADMIN_ROLE` - roleId `0` - Super admin of the Access Manager. Authorized to perform Access Manager configuration actions.
- `INFRA_CONFIG_ROLE` - roleId `1` - Authorized to configure the MakinaLite registry and bridge encoder contracts.
- `STRATEGY_DEPLOYMENT_ROLE` - roleId `2` - Authorized to deploy new MakinaLite modules.
- `INFRA_UPGRADE_ROLE` - roleId `6` - Authorized to upgrade proxies of the MakinaLite infrastructure contracts.
- `GUARDIAN_ROLE` - roleId `7` - Authorized to cancel operations scheduled with the other roles.
