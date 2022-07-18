import { TILE_TYPE } from './../../tasks/util/types/index';

export interface GameConfig {
  address: string;
  network: string;
  deploymentId: string;
  map: TILE_TYPE[][];
}
