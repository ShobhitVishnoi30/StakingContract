// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const accounts = await hre.ethers.getSigners();

  const StakingToken = await hre.ethers.getContractFactory("StakingToken");
  const stakingToken = await StakingToken.deploy();

  await stakingToken.deployed();

  const RewardToken = await hre.ethers.getContractFactory("RewardToken");
  const rewardToken = await RewardToken.deploy();

  await rewardToken.deployed();

  // We get the contract to deploy
  const StakingRewards = await hre.ethers.getContractFactory("StakingRewards");
  const stakingReward = await StakingRewards.deploy(
    accounts[0].address,
    rewardToken.address,
    stakingToken.address
  );

  await stakingReward.deployed();

  console.log("Staking Reward deployed to:", stakingReward.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
