# MakinaX Smart Contracts

This repository contains the smart contracts of MakinaX.

## Background

MakinaX is a lightweight version of the Makina protocol, designed for executing advanced DeFi investment strategies through [Safe](https://safe.global/) multisig wallets. It provides institutional-grade strategy execution with strong risk controls, operating as a Safe module that manages positions, executes swaps, and bridges assets on behalf of the Safe.

Each MakinaX module is deployed on top of a Safe and can be configured with a set of pre-approved [Weiroll](https://github.com/EnsoBuild/enso-weiroll) instructions, loss limits, pricing routes, and role-based access controls. Operators execute strategy actions through the module, while the Safe retains full authority over configuration and risk parameters. A configurable operating mode adjusts how tightly operator actions are constrained on-chain. Instruction Merkle proof verification is always enforced, regardless of operating mode.

See `SPECIFICATIONS.md` and `PERMISSIONS.md` for more details.

## Contracts Overview

| Filename                       | Description                                                                                               |
| ------------------------------ | --------------------------------------------------------------------------------------------------------- |
| `MakinaXModule.sol`            | Core module managing positions, swaps, bridging, and oracles on behalf of a Safe.                         |
| `MakinaXRegistry.sol`          | Stores addresses of shared protocol components (e.g. factory, module implementation, or bridge encoders). |
| `ModuleFactory.sol`            | Factory for deterministic deployment of MakinaXModule clones.                                             |
| `FlashLoanModule.sol`          | Handles flash loan requests and callbacks via Morpho.                                                     |
| `AcrossV4BridgeEncoder.sol`    | Encodes bridge transfer data for Across V4.                                                               |
| `CctpV2BridgeEncoder.sol`      | Encodes bridge transfer data for Circle CCTP V2.                                                          |
| `LayerZeroV2BridgeEncoder.sol` | Encodes bridge transfer data for LayerZero V2.                                                            |

## Installation

Follow [this link](https://book.getfoundry.sh/getting-started/installation) to install the Foundry toolchain.

## Submodules

Run below command to include/update all git submodules like forge-std, openzeppelin contracts etc (`lib/`)

```shell
git submodule update --init --recursive
```

## Dependencies

Run below command to include project dependencies like prettier and solhint (`node_modules/`)

```shell
yarn
```

### Build

Run below command to compile contracts that require IR-based codegen (`test-ir/`)

```shell
yarn build:ir
```

Run below command to compile all other contracts

```shell
forge build
```

### Test

```shell
forge test
```

### Coverage

```shell
yarn coverage
```

### Format

```shell
forge fmt
```

### Lint

```shell
yarn lint
```
