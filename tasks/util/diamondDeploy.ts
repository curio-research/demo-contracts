import { Curio } from '../../typechain-types/Curio';
import { Signer } from 'ethers';
import { deployProxy } from './deployHelper';
import { HardhatRuntimeEnvironment, Libraries } from 'hardhat/types';
import { getSelectors, FacetCutAction } from './diamondHelper';

export async function deployDiamond(hre: HardhatRuntimeEnvironment, deployArgs: any[]) {
  const accounts = await hre.ethers.getSigners();
  const contractOwner = accounts[0];

  // deploy DiamondCutFacet
  const DiamondCutFacet = await hre.ethers.getContractFactory('DiamondCutFacet');
  const diamondCutFacet = await DiamondCutFacet.deploy();
  await diamondCutFacet.deployed();
  console.log('✦ DiamondCutFacet:', diamondCutFacet.address);

  // deploy Diamond
  const Diamond = await hre.ethers.getContractFactory('Diamond');
  const diamond = await Diamond.deploy(contractOwner.address, diamondCutFacet.address);
  await diamond.deployed();
  console.log('✦ Diamond:', diamond.address);

  // deploy DiamondInit
  // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
  // Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
  const DiamondInit = await hre.ethers.getContractFactory('DiamondInit');
  const diamondInit = await DiamondInit.deploy();
  await diamondInit.deployed();

  // deploy facets
  const FacetNames = ['DiamondLoupeFacet', 'OwnershipFacet'];
  const cut = [];
  for (const FacetName of FacetNames) {
    const Facet = await hre.ethers.getContractFactory(FacetName);

    const facet = await Facet.deploy();
    await facet.deployed();

    console.log(`✦ ${FacetName}: ${facet.address}`);
    cut.push({
      facetAddress: facet.address,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(facet),
    });
  }

  // upgrade diamond with facets
  const diamondCut = await hre.ethers.getContractAt('IDiamondCut', diamond.address);
  let tx;
  let receipt;

  // call to init function. add initial state setting parameters. this acts as the constructor essentially
  let functionCall = diamondInit.interface.encodeFunctionData('init', deployArgs); // encodes data functions into bytes i believe
  tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall);
  // console.log("✦ Diamond cut tx: ", tx.hash);

  receipt = await tx.wait();
  if (!receipt.status) {
    throw Error(`Diamond upgrade failed: ${tx.hash}`);
  }
  return diamond.address;
}

// deploy all facets

interface Facet {
  name: string;
  libraries?: Libraries;
}

export const deployFacets = async (hre: HardhatRuntimeEnvironment, diamondAddress: string, facets: Facet[], signer: Signer) => {
  const facetContracts = [];

  for (let i = 0; i < facets.length; i++) {
    const facetName: string = facets[i].name;

    const facet = await deployProxy<any>(facetName, signer, hre, [], facets[i].libraries);
    // const facet = await (await hre.ethers.getContractFactory(facetName, { libraries: facets[i].libraries })).deploy();
    await facet.deployed();

    facetContracts.push(facet);
  }

  const diamond = await hre.ethers.getContractAt('Curio', diamondAddress);
  const addresses = [];

  // loop through all facets
  for (let i = 0; i < facetContracts.length; i++) {
    const currentFacet = facetContracts[i];

    addresses.push(currentFacet.address);
    const selectors = getSelectors(currentFacet); // get all selectors and upload

    const tx = await diamond.diamondCut(
      [
        {
          facetAddress: currentFacet.address,
          action: FacetCutAction.Add,
          functionSelectors: selectors,
        },
      ],
      hre.ethers.constants.AddressZero,
      '0x',
      { gasLimit: 800000 }
    );

    const receipt = await tx.wait();
    if (!receipt.status) {
      throw Error(`Diamond upgrade failed: ${tx.hash}`);
    }

    // result = await diamondLoupeFacet.facetFunctionSelectors(
    //   currentFacet.address
    // );

    // const result = await diamond.facetFunctionSelectors(currentFacet.address);
    // console.log(result);
  }
};

export const getDiamond = async (hre: HardhatRuntimeEnvironment, diamondAddress: string): Promise<Curio> => {
  const res: any = await hre.ethers.getContractAt('Curio', diamondAddress);
  return res;
};
