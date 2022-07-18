# Game Smart Contracts

## Setup

- `contracts` directory contains game smart contracts using the [Diamond](https://eips.ethereum.org/EIPS/eip-2535) standard.
- `tasks` directory contains game constants, map generation, and deployment-related code.
- `test` directory contains tests for contracts using [Foundry](https://github.com/foundry-rs/foundry).

Make sure that Yarn, Node, and Hardhat are installed globally. Run `yarn install` first to install dependencies.

## How to Use

To run Foundry tests use `yarn forge-test`.

To deploy the contracts locally, first spin up a local network using `npx hardhat node`. Then, deploy using `npx hardhat deploy --network <NETWORK_NAME>`.

To deploy the testing map (hardcoded, not randomly generated), use `npx hardhat deploy --network localhost --fixmap`.

## About Curio

Curio Research is an on-chain gaming lab. Visit Curio's [official website](https://curio.gg) and [Twitter](https://twitter.com/0xcurio) for more information about us.
