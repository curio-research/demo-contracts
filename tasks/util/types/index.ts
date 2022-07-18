export enum TILE_TYPE {
  COAST = 0,
  INLAND = 1,
  WATER = 2,
  PORT = 3,
  CITY = 4,
}

export enum TROOP_NAME {
  ARMY,
  TROOP_TRANSPORT,
  DESTROYER,
  CRUISER,
  BATTLESHIP,
  FIGHTER_JET,
}

export interface MapInput {
  width: number;
  height: number;
  numPorts: number;
  numCities: number;
}

export interface RenderInput {
  /**
   * Higher values correspond to larger continents and oceans.
   */
  sizeFactor: number;

  numLandColors: number;
  numWaterColors: number;

  /**
   * Higher values correspond to more water in the map.
   * Must be in the interval (0, 1). Default is 0.55.
   */
  waterNoiseCutoff: number;

  /**
   * Lower values allow for darker colors, allowing more variation in map colors.
   * Must be in the interval [0, 100]. Default is 40.
   */
  colorLowestPercent: number;

  /**
   * Size multiplier for Perlin matrix responsible for plate tectonics versus that for granular details.
   */
  plateSizeMultiplier: number;

  /**
   * A ratio array for superposing multiple Perlin noise matrices.
   * Numbers in ratio must sum up to 1.
   */
  superpositionRatio: number[];
}

export interface ColorsAndCutoffs {
  noiseCutoffs: number[];
  colors: number[][];
}

export interface TileMapOutput {
  tileMap: TILE_TYPE[][];
  portTiles: Position[];
  cityTiles: Position[];
}

export interface AllGameMapsOutput {
  tileMap: TILE_TYPE[][];
  portTiles: Position[];
  cityTiles: Position[];
  colorMap: number[][][];
}

export interface Position {
  x: number;
  y: number;
}
