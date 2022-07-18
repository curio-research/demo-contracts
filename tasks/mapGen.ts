import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { RENDER_CONSTANTS } from './util/constants';
import { generateGameMaps } from './util/mapHelper';

task('map', 'map tests')
  .addFlag('port', 'port to frontend') // default is to call port
  .setAction(async (args: any, hre: HardhatRuntimeEnvironment) => {
    const map = generateGameMaps(
      {
        width: 20,
        height: 20,
        numPorts: 100,
        numCities: 100,
      },
      RENDER_CONSTANTS
    );
  });
