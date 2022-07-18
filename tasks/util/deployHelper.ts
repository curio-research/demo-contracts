import { Signer, Contract } from 'ethers';
import { FactoryOptions, HardhatRuntimeEnvironment } from 'hardhat/types';
import { LOCALHOST_RPC_URL, LOCALHOST_WS_RPC_URL } from './constants';
import { TileMapOutput } from './types';
import * as path from 'path';
import * as fsPromise from 'fs/promises';
import * as fs from 'fs';

// deploy proxy used in hre
export const deployProxy = async <C extends Contract>(contractName: string, signer: Signer, hre: HardhatRuntimeEnvironment, contractArgs: unknown[], libs?: FactoryOptions['libraries']): Promise<C> => {
  // add retry ?
  const factory = await hre.ethers.getContractFactory(contractName, libs ? { libraries: libs } : signer);
  const contract = await factory.deploy(...contractArgs);
  await contract.deployTransaction.wait();
  return contract as C;
};

export const printDivider = () => {
  console.log('------------------------------------');
};

export const rpcUrlSelector = (networkName: string): string[] => {
  if (networkName === 'localhost') {
    return [LOCALHOST_RPC_URL, LOCALHOST_WS_RPC_URL];
  } else if (networkName === 'optimismKovan') {
    return [process.env.KOVAN_RPC_URL!, process.env.KOVAN_WS_RPC_URL!];
  }
  return [];
};

export const LOCAL_MAP_PREFIX = 'MAP-';

export const saveMapToLocal = async (tileMapOutput: TileMapOutput) => {
  const mapsDir = path.join(path.join(__dirname), '..', 'maps');
  if (!fs.existsSync(mapsDir)) fs.mkdirSync(mapsDir);

  let mapIndex = (await fsPromise.readdir(mapsDir)).length;
  let mapPath: string;
  do {
    mapPath = path.join(mapsDir, `${LOCAL_MAP_PREFIX}${mapIndex}.json`);
    mapIndex++;
  } while (fs.existsSync(mapPath));

  await fsPromise.writeFile(mapPath, JSON.stringify(tileMapOutput));
};

export const loadLocalMap = (mapIndex: number): TileMapOutput => {
  const mapsDir = path.join(path.join(__dirname), '..', 'maps');
  const mapPath = path.join(mapsDir, `${LOCAL_MAP_PREFIX}${mapIndex}.json`);
  if (!fs.existsSync(mapsDir) || !fs.existsSync(mapPath)) {
    throw new Error('map not found');
  }

  const raw = fs.readFileSync(mapPath).toString();
  const tileMapOutput = JSON.parse(raw);
  if (!tileMapOutput.tileMap || !tileMapOutput.portTiles) throw new Error('something is wrong with stored maps');
  return tileMapOutput;
};
