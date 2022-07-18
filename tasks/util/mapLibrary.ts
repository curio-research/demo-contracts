import { Position, TileMapOutput, TILE_TYPE } from './types';
// Contains fixed maps for game

/////////////////////////////////////////////////////////////
// testingMap
/////////////////////////////////////////////////////////////

const testingMap: TILE_TYPE[][] = [
  [1, 1, 4, 1, 3, 2, 2, 2, 2, 2],
  [1, 1, 1, 1, 1, 2, 2, 2, 2, 2],
  [4, 1, 1, 1, 3, 2, 2, 2, 2, 2],
  [1, 1, 1, 1, 1, 2, 2, 2, 2, 2],
  [3, 1, 3, 1, 1, 2, 2, 2, 2, 2],
  [2, 2, 2, 2, 2, 2, 2, 2, 2, 2],
  [2, 2, 2, 2, 2, 2, 2, 2, 2, 2],
  [2, 2, 2, 2, 2, 2, 2, 2, 2, 2],
  [2, 2, 2, 2, 2, 2, 2, 2, 2, 2],
  [2, 2, 2, 2, 2, 2, 2, 2, 2, 2],
];
const testingMapPortTiles: Position[] = [
  { x: 0, y: 4 },
  { x: 2, y: 4 },
  { x: 4, y: 2 },
  { x: 4, y: 0 },
];
const testingMapCityTiles: Position[] = [
  { x: 0, y: 2 },
  { x: 2, y: 0 },
];
export const testingMapTileOutput: TileMapOutput = {
  tileMap: testingMap,
  portTiles: testingMapPortTiles,
  cityTiles: testingMapCityTiles,
};

/////////////////////////////////////////////////////////////
// MEDITERRAINEAN MAP
/////////////////////////////////////////////////////////////

interface Stronghold {
  name: string;
  position: Position;
}

const W = 2;
const L = 1;
const C = 0;
const P = 3;
const I = 4;

const MEDITERRAINEAN_GEOGRAPHY = [
  [W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, L, L],
  [W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, L, L, L],
  [W, W, W, W, L, L, L, L, L, L, L, W, W, W, W, L, L, L, L, L],
  [W, W, W, W, L, L, L, L, L, L, L, W, W, W, L, L, L, L, L, L],
  [W, W, W, W, L, L, L, L, L, L, L, W, L, L, L, L, L, L, L, L],
  [W, W, W, W, L, L, L, L, L, L, L, W, W, L, L, L, L, L, L, L],
  [W, W, W, W, L, L, L, L, L, L, L, W, W, L, L, L, L, L, L, L],
  [W, W, W, W, L, L, L, L, L, L, W, W, W, L, L, L, L, L, L, L],
  [L, L, L, L, L, L, L, L, L, L, W, W, L, L, L, L, L, L, L, L],
  [L, L, L, L, L, L, L, W, W, W, W, W, L, L, L, L, L, L, L, L],
  [L, L, L, L, L, L, W, W, W, W, W, L, L, L, L, L, L, L, L, L],
  [L, L, L, L, W, W, W, W, W, W, W, L, L, L, L, L, L, L, L, L],
  [L, L, L, L, W, W, W, W, W, W, W, L, L, L, L, L, L, L, L, L],
  [L, L, L, L, W, W, W, W, W, W, W, L, L, L, L, L, L, L, L, L],
  [L, L, L, L, W, W, W, W, W, W, W, L, L, L, L, L, L, L, L, L],
  [L, L, L, W, W, L, W, L, L, W, W, L, L, L, L, L, L, L, L, L],
  [L, L, L, L, W, W, W, W, W, W, W, L, L, W, L, L, L, L, L, L],
  [L, L, L, L, L, W, W, W, W, W, W, W, W, W, W, L, L, L, L, L],
  [L, L, W, L, L, L, W, W, W, W, W, W, W, W, W, L, L, L, L, L],
  [L, L, W, W, L, L, L, W, W, W, L, W, W, W, W, L, L, L, L, L],
  [L, L, L, W, W, L, L, L, W, W, L, W, W, W, W, W, L, L, L, L],
  [L, L, L, L, W, W, L, L, L, L, W, W, W, W, W, W, W, L, L, L],
  [L, L, L, L, L, W, W, L, W, W, W, W, W, W, W, W, W, L, L, L],
  [L, L, L, L, L, W, W, W, W, W, W, W, W, W, W, W, W, L, L, L],
  [L, L, L, L, L, L, L, L, W, W, W, W, W, W, W, W, W, L, L, L],
  [L, L, L, L, L, L, L, L, L, L, W, W, W, W, W, L, L, L, L, L],
  [L, L, L, L, L, L, L, L, L, L, L, W, W, W, W, L, L, L, L, L],
  [L, L, L, L, L, L, L, W, W, L, W, W, W, W, W, W, L, L, L, L],
  [L, L, L, L, L, L, L, W, W, W, W, W, L, W, W, W, L, L, L, L],
  [L, L, L, L, L, L, L, W, W, W, W, W, W, W, W, W, L, L, L, L],
  [L, L, L, L, W, W, L, W, L, L, L, W, W, W, W, W, W, L, L, L],
  [L, L, W, W, W, W, W, W, L, L, L, W, W, W, W, W, W, L, L, L],
  [L, W, W, W, W, W, W, L, L, L, L, W, W, W, W, W, L, L, L, L],
  [L, W, W, W, W, W, W, L, L, L, L, W, W, W, W, W, L, L, L, L],
  [L, W, W, W, W, W, L, L, L, L, L, L, W, L, W, W, W, W, L, L],
  [L, L, L, W, W, W, L, L, L, L, L, W, W, W, W, W, L, L, L, L],
  [L, W, L, W, W, W, L, L, L, L, L, W, W, W, L, L, L, L, L, L],
  [W, W, W, W, W, W, W, L, L, L, L, L, L, L, L, L, L, L, L, L],
  [W, W, L, W, W, W, W, L, L, L, L, L, L, L, L, L, L, L, L, L],
  [L, L, L, L, W, W, W, L, L, L, L, L, L, L, L, L, L, L, L, L],
  [L, L, L, L, L, W, W, L, L, L, L, L, L, L, L, L, L, L, L, L],
  [L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L],
  [L, L, L, L, L, L, L, L, L, W, L, L, L, L, L, L, L, L, L, L],
];

const tier1Strongholds: Stronghold[] = [
  { name: 'Madrid', position: { x: 5, y: 7 } },
  { name: 'Carthage', position: { x: 16, y: 11 } },
  { name: 'Rome', position: { x: 18, y: 5 } },
  { name: 'Athens', position: { x: 27, y: 9 } },
  { name: 'Constantinople', position: { x: 30, y: 6 } },
  { name: 'Cairo', position: { x: 33, y: 16 } },
];

const tier2Strongholds: Stronghold[] = [
  { name: 'Rabat', position: { x: 3, y: 14 } },
  { name: 'Barcelona', position: { x: 10, y: 5 } },
  { name: 'Algeris', position: { x: 11, y: 11 } },
  { name: 'Geneva', position: { x: 13, y: 1 } },
  { name: 'Florence', position: { x: 17, y: 3 } },
  { name: 'Palermo', position: { x: 19, y: 10 } },
  { name: 'Vienna', position: { x: 20, y: 0 } },
  { name: 'Bucharest', position: { x: 28, y: 2 } },
  { name: 'Crete', position: { x: 28, y: 12 } },
  { name: 'Ankara', position: { x: 34, y: 8 } },
  { name: 'Jerusalem', position: { x: 36, y: 15 } },
  { name: 'Damascus', position: { x: 38, y: 13 } },
];

const addCoasts = (map: number[][]): number[][] => {
  const width = map.length;
  const height = map[0].length;
  let lW: boolean, rW: boolean, uW: boolean, dW: boolean;

  for (let x = 0; x < width; x++) {
    for (let y = 0; y < height; y++) {
      if (map[x][y] === L) {
        lW = x > 0 && map[x - 1][y] === W;
        rW = x < width - 1 && map[x + 1][y] === W;
        uW = y > 0 && map[x][y - 1] === W;
        dW = y < height - 1 && map[x][y + 1] === W;
        if (lW || rW || uW || dW) {
          map[x][y] = C;
        }
      }
    }
  }

  return map;
};

const addStrongholds = (map: number[][], strongholds: Stronghold[]): TileMapOutput => {
  const portTiles: Position[] = [];
  const cityTiles: Position[] = [];

  strongholds.forEach((s) => {
    if (map[s.position.x][s.position.y] === C) {
      map[s.position.x][s.position.y] = P;
      portTiles.push(s.position);
    } else {
      map[s.position.x][s.position.y] = I;
      cityTiles.push(s.position);
    }
  });

  return { tileMap: map, portTiles, cityTiles };
};

export const MEDITERRAINEAN_MAP = addStrongholds(addCoasts(MEDITERRAINEAN_GEOGRAPHY), [...tier1Strongholds, ...tier2Strongholds]);
