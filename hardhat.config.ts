import fs from 'fs';
import 'hardhat-diamond-abi';
import { task } from 'hardhat/config';
import '@typechain/hardhat';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import 'hardhat-contract-sizer';
import 'hardhat-preprocessor';
require('dotenv').config();

// tasks
import './tasks/port';
import './tasks/deploy';
import './tasks/mapGen';

// to get the file size of each smart contract, run:
// yarn run hardhat size-contracts

const { USER1_PK, USER2_PK, OPTIMISM_KOVAN_RPC_URL, GNOSIS_OPTIMISM_RPC_URL, GNOSIS_RPC_URL, LOCALHOST_USER1_PK, LOCALHOST_USER2_PK, CONSTELLATION_RPC_URL, TAILSCALE_MAIN } = process.env;

export default {
  defaultNetwork: 'localhost',

  solidity: {
    version: '0.8.4',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  diamondAbi: {
    name: 'Curio',
    include: ['Facet', 'Util'],
    strict: true, // check for overlapping function names
  },

  networks: {
    optimismKovan: {
      url: OPTIMISM_KOVAN_RPC_URL,
      accounts: [USER1_PK, USER2_PK],
      chainId: 69,
    },
    tailscale: {
      url: `http://${TAILSCALE_MAIN}:8545`,
      accounts: [LOCALHOST_USER1_PK, LOCALHOST_USER2_PK],
      chainId: 1337,
    },
    gnosisOptimism: {
      url: GNOSIS_OPTIMISM_RPC_URL,
      accounts: [USER1_PK, USER2_PK],
      chainId: 300,
    },
    gnosis: {
      url: GNOSIS_RPC_URL,
      accounts: [USER1_PK, USER2_PK],
      chainId: 100,
    },
    constellation: {
      url: CONSTELLATION_RPC_URL,
      accounts: [USER1_PK, USER2_PK],
      chainId: 2901,
    },
    hardhat: {
      chainId: 1337,
      allowUnlimitedContractSize: true,
      blockGasLimit: 100000000000,
      mining: {
        auto: true,
        // interval: 200,
      },
    },
  },

  paths: {
    cache: './cache_hardhat', // Use a different cache for Hardhat than Foundry
  },

  preprocess: {
    eachLine: (hre: any) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match('"' + find)) {
              line = line.replace('"' + find, '"' + replace);
            }
          });
        }
        return line;
      },
    }),
  },
};
// script copy pasta'd from Foundry book

function getRemappings() {
  return fs
    .readFileSync('remappings.txt', 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line) => line.trim().split('='));
}

task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});
