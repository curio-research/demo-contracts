import { BigNumber as BN, BigNumberish } from 'ethers';

export const decodeBNArr = (arr: BN[]): number[] => {
  return arr.map((arr) => arr.toNumber());
};

export const decodeBigNumberishArr = (arr: BigNumberish[]): number[] => {
  return arr.map((arr) => Number(arr));
};
