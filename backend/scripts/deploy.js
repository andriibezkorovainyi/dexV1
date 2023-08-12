const hre = require("hardhat");

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  // Деплоим контракт токена
  const tokenContract = await hre.ethers.deployContract('Token');
  await tokenContract.waitForDeployment();
  console.log('Token contract deployed to: ', tokenContract.target);

  // Деплоим контракт биржи
  const exchangeContract = await hre.ethers.deployContract('Swap', [tokenContract.target]);
  await exchangeContract.waitForDeployment();
  console.log('Swap contract deployed to: ', exchangeContract.target);

  // Ждём 30 секунд чтобы Etherscan успел обновить данные
  await sleep(30 * 1000);

  // Верифицируем контракты на Etherscan
  await hre.run('verify:verify', {
    address: tokenContract.target,
    constructorArguments: [],
    contract: 'contracts/Token.sol:Token'
  });
  await hre.run('verify:verify', {
    address: exchangeContract.target,
    constructorArguments: [tokenContract.target],
    contract: 'contracts/Swap.sol:Swap'
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
