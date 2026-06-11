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

#### Fund Custody

The module isn't meant to hold ERC20 balances between operations. Swaps, bridges, and flash loans pull inputs from the Safe and forward outputs back within the same call, while Weiroll instructions run directly in the Safe's context. `sweepERC20` (Safe-only) recovers any ERC20 that lands on the module by mistake.

#### Operating Mode

The Safe can set the module's operating mode, which determines the on-chain safety checks enforced on operator actions. The three modes are ordered by increasing restriction:

- **OPEN**: No additional restrictions are enforced.
- **FENCED**: Restrictions are enforced on value-exit paths — swaps and bridge transfers — namely value loss limits, cooldowns, bridge recipient whitelisting, and route/OFT registration checks. Position management remains unrestricted.
- **WALLED**: All `FENCED` restrictions, plus position management restrictions — mandatory accounting, value preservation checks, and instruction cooldowns.

Instruction Merkle proof verification is always enforced, regardless of operating mode.

### Position Management

Position management is handled by the `WeirollComponent`, which leverages the [Weiroll](https://github.com/EnsoBuild/enso-weiroll) command-chaining framework to execute DeFi operations through the Safe via delegatecall.

#### Instructions

A set of instructions can be pre-approved and registered in a Merkle tree, whose root is stored in the module and used to verify authorization proofs. Each instruction includes a bitmap that determines which state parameters are fixed (included in the Merkle leaf) and which are variable (excluded from the hash). This enables a single pre-approved instruction to be executed with different parameters for designated slots.

Instructions can be of four different types:

- **MANAGEMENT**: Modifies the size of a position. May be associated with an `ACCOUNTING` instruction. In `WALLED` mode, an associated `ACCOUNTING` instruction is required.
- **ACCOUNTING**: Calculates the asset amounts used to value a position. Applies to one or more `MANAGEMENT` instructions for the matching position ID.
- **HARVEST**: Collects rewards earned by open positions from external protocols.
- **FLASHLOAN_MANAGEMENT**: Modifies the size of a position in the context of a flash loan, as part of an outer `MANAGEMENT` instruction. A `FLASHLOAN_MANAGEMENT` instruction is always associated with a `MANAGEMENT` instruction and can only be executed in its scope.

Each `Instruction` object includes an `affectedTokens` list. For `MANAGEMENT` instructions, this list must include all tokens spent by the instruction. For `ACCOUNTING` instructions, this list must include all tokens in which the position value is expressed. For `HARVEST` and `FLASHLOAN_MANAGEMENT` instructions, this list is ignored.

#### Position Value Loss Checks

When in `WALLED` mode, position management operations enforce value loss limits. After each management instruction, the module compares the position value change against the change in affected token balances held by the Safe. For example in the case of asset positions:

- For position increases: the position value gained must be within `maxPositionIncreaseLossBps` of the tokens spent.
- For position decreases: the tokens received must be within `maxPositionDecreaseLossBps` of the position value lost.

For debt positions the token flow is inverted (increasing the debt brings tokens in, decreasing it sends tokens out), so the same limits apply against the opposite flow direction. See the validation matrix in `IWeirollComponent.managePosition` for the exact rules.

**Limitation:** these value loss checks cannot be robustly enforced for instructions that embed arbitrary operator-supplied calldata, such as routing through a DEX aggregator. Such calldata can hand control to third parties mid-execution through reentrant intermediary tokens or protocol callbacks, which can inflate the Safe's measured balances (e.g. by settling a pending inbound bridge transfer, claiming a bridge refund, claiming permissionless rewards), thereby masking a real loss. Whitelisting such instructions is therefore discouraged.

#### Instruction Cooldown

When in `WALLED` mode, management instructions are subject to a cooldown. After each successful management instruction, the module records a timestamp keyed by the tuple `(positionId, commands, direction)`, where `direction` reflects whether the operation increased or decreased the position value. Re-running the same management script on the same position in the same direction is rejected until the configured instruction cooldown duration has elapsed.

#### Assumptions

The protocol relies on specific assumptions on the instructions. Some are always required for correct behavior, while others are only relevant in `WALLED` mode but remain best practice regardless.

- **ACCOUNTING**:
  - They must not introduce changes in position states or token balances.
  - Their output must be resistant to manipulation by third parties (e.g. via sandwich attacks).
  - The `affectedTokens` list must include exactly all tokens in which the position size is expressed.
  - Their output state must start with an ordered list of amounts (one amount per slot) matching the order of `affectedTokens`, followed by an end-of-args flag.
- **MANAGEMENT**:
  - The `affectedTokens` list must include exactly all tokens spent by the instruction.
  - They should not leave persistent ERC20 approvals from the Safe to external contracts. Any approval granted during execution should be consumed or revoked before the instruction returns.
- **HARVEST**:
  - They should be restricted to receive-only operations and should not spend any tokens that are initially held by the Safe.
- **FLASHLOAN_MANAGEMENT**:
  - They must not result in token balance changes for tokens that are not in the `affectedTokens` list of the associated `MANAGEMENT` instruction.
  - They should not leave persistent ERC20 approvals from the Safe to external contracts.

### Token Swapping

The `SwapComponent` enables the module to execute token swaps through external DEX protocols using unverified calldata. For each registered swapper, an approval target and an execution target are configured. The module pulls funds from the Safe, approves the approval target, executes the swap calldata on the execution target, revokes the approval, and returns the output tokens to the Safe.

When in `FENCED` or `WALLED` mode, swap operations enforce a value loss limit (`maxSwapLossBps`) by comparing the output value against the input value using oracle prices.

#### Fees

A configurable swap fee rate, set by the provider, is applied to every swap output. Fees are transferred to the fee collector address stored in the `MakinaLiteRegistry`. The fee rate is expressed as a fraction of `1e18` (i.e., `1e18` = 100%).

#### Cooldown

When in `FENCED` or `WALLED` mode, swaps are subject to a cooldown. The module records the timestamp of the last successful swap and rejects subsequent swaps until the configured swap cooldown duration has elapsed. The cooldown is global to the swap component and is not segmented by swapper, input token, or output token. It also applies to swaps performed as part of a `harvest` call. A harvest carrying more than one swap order therefore requires `OPEN` mode, or a swap cooldown of zero.

### Oracle Registry

The `OracleRegistry` component prices tokens in a reference currency (e.g. USD) by aggregating price feeds that implement Chainlink's `AggregatorV2V3Interface`, using either a single feed or a two-feed path. For each feed, a staleness threshold is configured.

The oracle is used for:

- Position value calculations during accounting.
- Value loss enforcement during swaps (`FENCED` or `WALLED` mode) and position management (`WALLED` mode).

#### Accounting Currency

By default, position values are expressed in the reference currency (address(0)). An optional accounting currency can be set per module, in which case position values are expressed in that token using the oracle's cross-token pricing.

### Token Bridging

The `BridgeComponent` enables cross-chain token transfers through a modular bridge encoder system. The module supports multiple bridge protocols via a set of `BridgeEncoder` contracts that each encode the appropriate calldata for a given external bridge.

For each bridge transfer, the module pulls the input token from the Safe and delegates the calldata encoding to the corresponding bridge encoder registered in the `MakinaLiteRegistry` for the given bridge ID.

#### Operating Mode Restrictions

When in `FENCED` or `WALLED` mode, bridge transfers enforce:

- **Recipient whitelisting**: The recipient on the destination chain must be whitelisted for that specific chain ID.
- **Value loss limits**: The minimum output amount must be within `maxBridgeLossBps` of the input amount.
- **Route/OFT registration checks**: Bridge-specific checks are enforced depending on the bridge protocol (e.g. route registration for Across V4, OFT registration for LayerZero V2).
- **Cooldown**: Outgoing transfers via a given bridge are rejected until the configured bridge cooldown duration has elapsed since the previous outgoing transfer through that same bridge. Each bridge ID has an independent cooldown clock.

The bridge loss check compares `inputAmount` and `minOutputAmount` directly, without oracle pricing or decimal scaling. It therefore assumes input and output tokens are homologous (same underlying value, one-to-one) and share the same number of decimals.

#### Supported Bridge Protocols

**Across V4** (`AcrossV4BridgeEncoder`): Routes tokens through the Across V4 SpokePool using `depositV3Now`. Supports configurable token routes (input token to output token per destination chain). In `FENCED` or `WALLED` mode, only registered routes are allowed.

**Circle CCTP V2** (`CctpV2BridgeEncoder`): Bridges tokens through Circle's Cross-Chain Transfer Protocol using `depositForBurnWithHook`. Maintains a mapping of EVM chain IDs to CCTP domains.

**LayerZero V2** (`LayerZeroV2BridgeEncoder`): Bridges tokens through LayerZero's OFT (Omnichain Fungible Token) standard. Maintains mappings of EVM chain IDs to LayerZero endpoint IDs and a registry of allowed OFT contracts. In `FENCED` or `WALLED` mode, only registered OFTs are allowed.

LayerZero transfers require a native gas fee to be paid alongside the transfer. The module therefore needs to hold a small native balance as a gas buffer. `sweepNative` (Safe-only) allows the Safe to recover this balance at any time.

### Flash Loans

The `FlashLoanModule` contract handles flash loan requests via [Morpho](https://morpho.org/). Flash loans are used in the context of `FLASHLOAN_MANAGEMENT` instructions to leverage flash-loaned funds during position management.

The flow operates as follows:

1. The Safe calls `requestFlashLoan` on the `FlashLoanModule`, specifying the taker module, token, amount, and the `FLASHLOAN_MANAGEMENT` instruction.
2. The `FlashLoanModule` requests the flash loan from Morpho.
3. Morpho calls back `onMorphoFlashLoan` on the `FlashLoanModule`.
4. The `FlashLoanModule` delegates execution to the taker module's `manageFlashLoan` function.
5. The taker module transfers the flash-loaned funds from the `FlashLoanModule` to the Safe.
6. The taker module executes the `FLASHLOAN_MANAGEMENT` instruction via the Safe.
7. The taker module instructs the Safe to transfer the repayment amount to the `FlashLoanModule`, which repays Morpho.

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
