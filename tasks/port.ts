import fs from 'fs-extra';
import path from 'path';
import { HardhatArguments, HardhatRuntimeEnvironment } from 'hardhat/types';
import { task } from 'hardhat/config';

task('port', 'compile and port contracts over to frontend repo').setAction(async (args: HardhatArguments, hre: HardhatRuntimeEnvironment) => {
  try {
    // delete items in existing directories
    await fs.emptydirSync(getDir('frontend', ''));
    await fs.emptydirSync(getDir('faucet', ''));

    // create factory folders in each
    await fs.mkdirSync(getDir('frontend', '/factories'));
    await fs.mkdirSync(getDir('faucet', '/factories'));

    // since hardhat-diamond-abi compiles all files into one, We need to port common.ts, Curio.ts, and Curio__factory.ts
    // NICE-TO-HAVE: selectively port files, search by file names in the subdirectories

    await portFile('/Curio.ts');
    await portFile('/common.ts');
    await portFile('/factories/Curio__factory.ts');

    // copy game configs
    const configFilePath = path.join(__dirname, '/game.config.json');
    const configClientPath = path.join(__dirname, '../../frontend/src/game.config.json');

    await fs.copyFileSync(configFilePath, configClientPath);
    console.log('✦ Porting complete!');
  } catch (err: any) {
    console.log(err.message);
  }
});

// helpers

const getDir = (repositoryName: string, filePath: string): string => {
  const prefixSelector = (repoName: string) => {
    if (repoName === 'local') return '../typechain-types';
    if (repoName === 'frontend') return '../../frontend/src/network/typechain-types';
    if (repoName === 'faucet') return '../../faucet/src/typechain-types';
  };
  return path.join(__dirname, `${prefixSelector(repositoryName)}${filePath}`);
};

const portFile = async (filePath: string): Promise<void> => {
  await fs.copyFileSync(getDir('local', filePath), getDir('frontend', filePath));
  await fs.copyFileSync(getDir('local', filePath), getDir('faucet', filePath));
};

// copy folder
const copyFolderSync = (from: string, to: string) => {
  fs.mkdirSync(to);
  fs.readdirSync(from).forEach((element) => {
    if (fs.lstatSync(path.join(from, element)).isFile()) {
      fs.copyFileSync(path.join(from, element), path.join(to, element));
    } else {
      copyFolderSync(path.join(from, element), path.join(to, element));
    }
  });
};
