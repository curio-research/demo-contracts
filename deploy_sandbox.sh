#!/bin/zsh
cd tasks; rm game.config.json; cd ..
for i in {1..$1}
do
    echo "####################################"
    echo "DEPLOYING GAME $i"
    npx hardhat deploy --network constellation --name sandbox
done
