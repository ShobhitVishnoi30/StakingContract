const { expect } = require("chai");
const { ethers } = require("hardhat");

let user1, user2, user3;

async function getSigners() {
  const accounts = await hre.ethers.getSigners();
  user1 = accounts[0];
  user2 = accounts[1];
  user3 = accounts[2];
}

describe("Setup & Test Contracts", async function () {
  it("Setting up the contracts & Testing", async function () {
    await getSigners();
  }).timedOut("200000s");
});
