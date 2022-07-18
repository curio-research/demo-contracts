import { Interface } from '@ethersproject/abi';
const hre = require('hardhat');

// this file is ran by Foundry tests to pipe js input back into solidity files

// interfaces
import HelperFacetInterface from '../../../out/HelperFacet.sol/HelperFacet.json';
import GetterFacetInterface from '../../../out/GetterFacet.sol/GetterFacet.json';
import EngineFacetInterface from '../../../out/EngineFacet.sol/EngineFacet.json';
import DiamondInitInerface from '../../../out/DiamondInit.sol/DiamondInit.json';

const nameToAbiMapping: any = {
  DiamondInit: DiamondInitInerface,
  EngineFacet: EngineFacetInterface,
  GetterFacet: GetterFacetInterface,
  HelperFacet: HelperFacetInterface,
};

const args = process.argv.slice(2);

if (args.length == 0) {
  console.log('no parameter. please give a contract name');
  process.exit(1);
} else if (args.length > 1) {
  console.log('too many contracts');
  process.exit(1);
}

async function getSelectors(contractName: string) {
  const contractInterface: Interface = new hre.ethers.utils.Interface(nameToAbiMapping[contractName].abi);

  const selectors = Object.keys(contractInterface.functions).map((signature) => contractInterface.getSighash(signature));

  const coded = hre.ethers.utils.defaultAbiCoder.encode(['bytes4[]'], [selectors]);

  process.stdout.write(coded);
}

getSelectors(args[0]);

// code attribution: inspired by https://github.com/Timidan
