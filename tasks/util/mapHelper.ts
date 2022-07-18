import { BigNumberish, BigNumber } from 'ethers';
import SimplexNoise from 'simplex-noise';
import { RenderInput, ColorsAndCutoffs, TileMapOutput, TILE_TYPE, AllGameMapsOutput, MapInput, Position } from './types';

//////////////////////////////////////////////////////////////////////
///////////////////////////// CONSTANTS //////////////////////////////
//////////////////////////////////////////////////////////////////////

/**
 * Larger values correspond to smaller continent sizes. Held constant.
 */
const INCREMENT = 1;

const xIncrement = INCREMENT;
const yIncrement = INCREMENT;

const MAX_UINT256 = BigInt(Math.pow(2, 256)) - BigInt(1);

//////////////////////////////////////////////////////////////////////
///////////////////////////// FUNCTIONS //////////////////////////////
//////////////////////////////////////////////////////////////////////

/**
 * Encode columns of a tile map using unique prime factorization.
 * @param tileMap
 * @param numInitTerrainTypes
 * @param batchSize
 * @returns a 2d array of encoded columns, each in batches
 */
export const encodeTileMap = (tileMap: TILE_TYPE[][], numInitTerrainTypes: number = 5, batchSize: number = 100): string[][] => {
  const result: string[][] = [];
  const numBatchPerCol = Math.floor(tileMap[0].length / batchSize);
  const lastBatchSize = tileMap[0].length % batchSize;

  let encodedCol: string[];
  let tempBatch: bigint;
  let k: number;

  for (let x = 0; x < tileMap.length; x++) {
    encodedCol = [];
    for (k = 0; k < numBatchPerCol; k++) {
      tempBatch = BigInt(0);
      for (let y = 0; y < batchSize; y++) {
        tempBatch += BigInt(tileMap[x][y]) * BigInt(numInitTerrainTypes) ** BigInt(y);
        if (tempBatch >= MAX_UINT256) throw new Error('Encoding exceeds uint256 max size');
      }
      encodedCol.push(tempBatch.toString());
    }
    if (lastBatchSize > 0) {
      tempBatch = BigInt(0);
      for (let y = 0; y < lastBatchSize; y++) {
        tempBatch += BigInt(tileMap[x][y]) * BigInt(numInitTerrainTypes) ** BigInt(y);
        if (tempBatch >= MAX_UINT256) throw new Error('Encoding exceeds uint256 max size');
      }
      encodedCol.push(tempBatch.toString());
    }
    result.push(encodedCol);
  }

  return result;
};

/**
 * Generate two 2d maps of tiles, one representing tile types and the other representing colors in RGB.
 * @param mapInput
 * @param renderInput
 * @returns a 2d matrix of tile types and a 2d matrix of RGB values
 */
export const generateGameMaps = (mapInput: MapInput, renderInput: RenderInput): AllGameMapsOutput => {
  // Use multiple layers of Perlin noise to generate randomized continents and oceans with plate tectonics
  const microNoiseMap: number[][] = generateNoiseMap(mapInput.width, mapInput.height, renderInput.sizeFactor);
  const plateNoiseMap: number[][] = generateNoiseMap(mapInput.width, mapInput.height, renderInput.sizeFactor * renderInput.plateSizeMultiplier);
  const noiseMap: number[][] = superpose([microNoiseMap, plateNoiseMap], renderInput.superpositionRatio);

  // Generate colors, cutoffs, and tile map
  const colorsAndCutoffs: ColorsAndCutoffs = getColorsAndCutoffs(renderInput);
  const colorMap: number[][][] = noiseMap.map((row: number[]) => {
    return row.map((val: number) => assignDepthColor(val, colorsAndCutoffs));
  });

  const { tileMap, portTiles, cityTiles } = placePortsAndCities(colorMap, mapInput.numPorts, mapInput.numCities);

  // Update colorMap with ports and cities
  portTiles.forEach((portTile) => {
    colorMap[portTile.x][portTile.y] = [100, 0, 0];
  });

  cityTiles.forEach((cityTile) => {
    colorMap[cityTile.x][cityTile.y] = [100, 100, 100];
  });

  return { tileMap, portTiles, cityTiles, colorMap };
};

export const generateEmptyMatrix = (mapWidth: number, mapHeight: number, defaultValue: any): any[][] => {
  const result: number[][] = [];
  for (let x = 0; x < mapWidth; x++) {
    const col: number[] = [];
    for (let y = 0; y < mapHeight; y++) {
      col.push(defaultValue);
    }
    result.push(col);
  }
  return result;
};

// This generates all game parameters needed to deploy the GameEngine.sol contract
export const getValue = (v: BigNumberish) => (v as BigNumber).toNumber();

interface islandIDMapCreatorRes {
  islandID: number;
  islandIDMarkerMap: number[][];
}

/**
 * Mark the islands and the corresponding tiles on a map.
 * @param tileMap
 * @returns number of islands as well as mapping to tiles
 */
const islandIDMapCreator = (tileMap: number[][]): islandIDMapCreatorRes => {
  const validLand = [TILE_TYPE.CITY, TILE_TYPE.COAST, TILE_TYPE.INLAND, TILE_TYPE.PORT];
  const islandIDMarkerMap: number[][] = new Array(tileMap.length).fill(null).map(() => new Array(tileMap[0].length).fill(0)); // a 2D number array marked with number the islandID
  let islandID = 0; // number of islands on the map

  // don't explore if its out of bounds, already explored, or is a water tile.
  const explore = (row: number, col: number, grid: number[][], islandID: number) => {
    if (row < 0 || col < 0 || row >= grid.length || col >= grid[row].length || grid[row][col] === TILE_TYPE.WATER || grid[row][col] === -1) {
      return;
    }

    // otherwise, proceed with DFS
    grid[row][col] = -1;
    islandIDMarkerMap[row][col] = islandID;

    explore(row, col + 1, grid, islandID);
    explore(row, col - 1, grid, islandID);
    explore(row + 1, col, grid, islandID);
    explore(row - 1, col, grid, islandID);
  };

  // go though each cell of the 2d array/grid
  for (let row = 0; row < tileMap.length; row++) {
    for (let col = 0; col < tileMap[row].length; col++) {
      if (validLand.includes(tileMap[row][col])) {
        islandID++;
        explore(row, col, tileMap, islandID);
      }
    }
  }

  return { islandID, islandIDMarkerMap };
};

/**
 * Generate noise matrix from Perlin noise.
 * @param mapWidth
 * @param mapHeight
 * @param sizeFactor determines average sizes of continents and oceans
 * @returns a 2d matrix of numbers between 0 and 1
 */
export const generateNoiseMap = (mapWidth: number, mapHeight: number, sizeFactor: number): number[][] => {
  const noise = new SimplexNoise();

  const scale = (val: number, min: number, max: number) => {
    return (val - min) / (max - min);
  };

  const _noiseMatrix: number[][] = [];

  for (let x = 0; x < mapWidth * xIncrement; x += xIncrement) {
    const col = [];
    for (let y = 0; y < mapHeight * yIncrement; y += yIncrement) {
      const val = noise.noise2D(x / sizeFactor, y / sizeFactor);
      col.push(Math.abs(scale(val, 0, 1)));
    }
    _noiseMatrix.push(col);
  }
  return _noiseMatrix;
};

/**
 * Populate list of color cutoffs and corresponding colors.
 * @param colorInput
 * @returns an array of noise level cutoffs and an array of corresponding RGB values
 */
export const getColorsAndCutoffs = (colorInput: RenderInput): ColorsAndCutoffs => {
  const { numLandColors, numWaterColors, waterNoiseCutoff, colorLowestPercent } = colorInput;

  const noiseCutoffs: number[] = [];
  const colors: number[][] = [];
  const waterNoiseIncrement = waterNoiseCutoff / numWaterColors;
  const landNoiseIncrement = (1 - waterNoiseCutoff) / numLandColors;
  const waterColorIncrement = (100 - colorLowestPercent) / numWaterColors;
  const landColorIncrement = (100 - colorLowestPercent) / numLandColors;

  for (let i = 1; i <= numWaterColors; i++) {
    // land is green
    noiseCutoffs.push(waterNoiseIncrement * i);
    colors.push([0, 0, colorLowestPercent + waterColorIncrement * (i - 1)]);
  }
  for (let i = 1; i <= numLandColors; i++) {
    // water is blue
    noiseCutoffs.push(waterNoiseCutoff + landNoiseIncrement * i);
    colors.push([0, 100 - landColorIncrement * i, 0]);
  }

  return { noiseCutoffs, colors };
};

/**
 * Automatically assign colors to a tile according to cutoffs.
 * @param noiseValue
 * @param colorsAndCutoffs
 * @returns a color array in the form of [R, G, B]
 */
export const assignDepthColor = (noiseValue: number, colorsAndCutoffs: ColorsAndCutoffs): number[] => {
  const { noiseCutoffs, colors } = colorsAndCutoffs;

  for (let i = 0; i < noiseCutoffs.length; i++) {
    if (noiseValue < noiseCutoffs[i]) return colors[i];
  }

  return [100, 0, 0]; // should not see any red on map
};

/**
 * Parse an [R, G, B] array to string.
 * @param rgbArray
 * @returns a CSS-format color string
 */
export const rgbArrayToString = (rgbArray: number[]): string => {
  const [r, g, b] = rgbArray;
  return `rgb(${r}%, ${g}%, ${b}%)`;
};

/**
 * Given an RGB color map, place random ports and cities.
 * @param colorMap
 * @param numPorts
 * @param numCities
 * @returns a 2d matrix of tile types
 */
export const placePortsAndCities = (colorMap: number[][][], numPorts: number, numCities: number): TileMapOutput => {
  let tileMap: TILE_TYPE[][] = generateEmptyMatrix(colorMap.length, colorMap[0].length, TILE_TYPE.WATER);

  // 1. Identify coastlines and inland areas.
  const coastlineTiles: Position[] = [];
  const inlandTiles: Position[] = [];
  const portTiles: Position[] = [];
  const cityTiles: Position[] = [];

  for (let x = 0; x < colorMap.length * xIncrement; x += xIncrement) {
    for (let y = 0; y < colorMap[0].length * yIncrement; y += yIncrement) {
      if (colorMap[x][y][1] > 0) {
        if ((x > 0 && colorMap[x - 1][y][1] == 0) || (x < colorMap.length - 1 && colorMap[x + 1][y][1] == 0) || (y > 0 && colorMap[x][y - 1][1] == 0) || (y < colorMap[0].length - 1 && colorMap[x][y + 1][1] == 0)) {
          tileMap[x][y] = TILE_TYPE.COAST;
          coastlineTiles.push({ x, y });
        } else {
          tileMap[x][y] = TILE_TYPE.INLAND;
          inlandTiles.push({ x, y });
        }
      }
    }
  }

  // 2. Randomly place ports and cities.
  let tileIndex: number;
  let tile: Position;

  // ---------------------------
  // ensure that every island has at least one coast
  // ---------------------------

  const { islandID, islandIDMarkerMap } = islandIDMapCreator(JSON.parse(JSON.stringify(tileMap)));
  const islandIdToMapping: Map<number, Position[]> = new Map();

  // loop through coastline tiles
  for (let i = 0; i < coastlineTiles.length; i++) {
    const coastlineTile = coastlineTiles[i];
    const x = coastlineTile.x;
    const y = coastlineTile.y;
    const islandID = islandIDMarkerMap[x][y];

    const islandArr = islandIdToMapping.get(islandID);
    if (!islandArr) {
      islandIdToMapping.set(islandID, [coastlineTile]);
    } else {
      islandArr.push(coastlineTile);
      islandIdToMapping.set(islandID, islandArr);
    }
  }

  // go through each island number
  // pick a random coast tile on each island and then add it to the island array.
  // this ensures that theres at least one city on each island!
  for (let i = 1; i < islandID + 1; i++) {
    const positionsByIslandID = islandIdToMapping.get(i);
    if (positionsByIslandID && numPorts > 0) {
      // Note: remove the `numPorts > 0` part to generate a port on every landmass regardless of specified port number
      const randomIslandTilePosition = positionsByIslandID[Math.floor(Math.random() * positionsByIslandID.length)];
      tileMap[randomIslandTilePosition.x][randomIslandTilePosition.y] = TILE_TYPE.PORT;
      portTiles.push({ x: randomIslandTilePosition.x, y: randomIslandTilePosition.y });
      numPorts--;
    }
  }

  while (numPorts > 0) {
    if (!coastlineTiles || coastlineTiles.length === 0) break;

    tileIndex = Math.floor(Math.random() * coastlineTiles.length);
    tile = coastlineTiles[tileIndex];
    tileMap[tile.x][tile.y] = TILE_TYPE.PORT;

    portTiles.push(tile);
    coastlineTiles.splice(tileIndex, 1);
    numPorts--;
  }

  while (numCities) {
    if (!inlandTiles || inlandTiles.length === 0) break;

    const inlandTileIdx = Math.floor(Math.random() * inlandTiles.length);
    const inlandTile = inlandTiles[inlandTileIdx];

    tileMap[inlandTile.x][inlandTile.y] = TILE_TYPE.CITY;

    cityTiles.push(inlandTile);
    inlandTiles.splice(inlandTileIdx, 1);
    numCities--;
  }

  return { tileMap, portTiles, cityTiles };
};

//////////////////////////////////////////////////////////////////////
////////////////////////////// HELPERS ///////////////////////////////
//////////////////////////////////////////////////////////////////////

/**
 * Superpose an array of 2d matrices based on a given ratio.
 * @param matrices
 * @param ratio
 * @returns a 2d matrix as the superposition result
 */
export const superpose = (matrices: number[][][], ratio: number[]): number[][] => {
  if (ratio.reduce((a, b) => a + b, 0) !== 1) throw new Error('Ratio must sum up to 1');

  const sum: number[][] = [];
  for (let i = 0; i < matrices[0].length; i++) {
    const col: number[] = [];
    for (let j = 0; j < matrices[0][0].length; j++) {
      let val = 0;
      for (let k = 0; k < matrices.length; k++) {
        val += matrices[k][i][j] * ratio[k];
      }
      col.push(val);
    }
    sum.push(col);
  }

  return sum;
};
