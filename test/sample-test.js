const { expect } = require("chai");
const { ethers } = require("hardhat");
const { mine } = require("@nomicfoundation/hardhat-network-helpers");

let user1, user2, user3;

async function getSigners() {
  const accounts = await hre.ethers.getSigners();
  user1 = accounts[0];
  user2 = accounts[1];
  user3 = accounts[2];
}

async function Testing() {
  const StakingToken = await hre.ethers.getContractFactory("StakingToken");
  const stakingToken = await StakingToken.deploy();

  await stakingToken.deployed();

  await stakingToken.mint(user1.address, 10000000);

  const RewardToken = await hre.ethers.getContractFactory("RewardToken");
  const rewardToken = await RewardToken.deploy();

  await rewardToken.deployed();

  await rewardToken.mint(user2.address, 1000000000);

  // We get the contract to deploy
  const StakingRewards = await hre.ethers.getContractFactory("StakingRewards");
  const stakingReward = await StakingRewards.deploy(
    user2.address,
    rewardToken.address,
    stakingToken.address
  );

  await stakingReward.deployed();
  describe("Testing Staking Reward Contract", function () {
    it("user should be able to stake their tokens", async function () {
      await stakingToken.connect(user1).approve(stakingReward.address, 1000);

      expect(await stakingReward.balanceOf(user1.address)).to.equal(0);

      await stakingReward.connect(user1).stake("100");

      expect(await stakingReward.balanceOf(user1.address)).to.equal("100");
    });

    it("user should not be able to stake tokens more than their balance", async function () {
      await stakingToken
        .connect(user1)
        .approve(stakingReward.address, 10000000);

      await expect(
        (await stakingToken.balanceOf(user1.address)).toString()
      ).to.equal("9999900");

      expect(await stakingReward.balanceOf(user1.address)).to.equal("100");

      await expect(
        stakingReward.connect(user1).stake("10000000")
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });

    it("user can not stake zero token", async function () {
      await expect(stakingReward.connect(user1).stake("0")).to.be.revertedWith(
        "Cannot stake 0"
      );
    });

    it("user can withdraw thier staked tokens", async function () {
      expect(await stakingReward.balanceOf(user1.address)).to.equal("100");

      await expect(
        (await stakingToken.balanceOf(user1.address)).toString()
      ).to.equal("9999900");

      await stakingReward.connect(user1).withdraw("50");

      expect(await stakingReward.balanceOf(user1.address)).to.equal("50");

      await expect(
        (await stakingToken.balanceOf(user1.address)).toString()
      ).to.equal("9999950");
    });

    it("user can not withdraw more token that they staked", async function () {
      expect(await stakingReward.balanceOf(user1.address)).to.equal("50");

      await expect(
        stakingReward.connect(user1).withdraw("51")
      ).to.be.revertedWith("exceeding staked amount");
    });

    it("reward distrbutor should be able to add rewards", async function () {
      await rewardToken
        .connect(user2)
        .approve(stakingReward.address, 1000000000);

      expect(await stakingReward.rewardRate()).to.equal(0);

      await stakingReward.connect(user2).notifyRewardAmount(1000000000);

      expect(await stakingReward.rewardRate()).to.equal(1653);
    });

    it("user should be able to claim reward tokes", async function () {
      expect(await rewardToken.balanceOf(user1.address)).to.equal(0);
      await stakingReward.connect(user1).getReward();

      expect(await rewardToken.balanceOf(user1.address)).to.equal(1653);
    });
  });
}

describe("Setup & Test Contracts", async function () {
  it("Setting up the contracts & Testing", async function () {
    await getSigners();
    await Testing();
  }).timedOut("200000s");
});
