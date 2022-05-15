import { expect } from "chai";
import { ethers } from "hardhat";

describe("OVixActions", function () {
  it("Exit", async function () {
    const [owner] = await ethers.getSigners()
    console.log("OWNER", owner.address)
    const OVixActions = await ethers.getContractFactory("OVixActions", owner);
    const oVixActions = await OVixActions.deploy();
    await oVixActions.deployed();

    await oVixActions.closePositions();

  });
});
