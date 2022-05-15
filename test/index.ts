import { expect } from "chai";
import { ethers, network } from "hardhat";
import { config } from 'dotenv'
config()

describe("OVixActions", function () {
  it("Exit", async function () {
    const IMPERSONATING = process.env.IMPERSONATE_ACCOUNT_FOR_TESTING || ''
    expect(IMPERSONATING).to.be.lengthOf(42)
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [IMPERSONATING],
    });

    const owner = await ethers.getSigner(IMPERSONATING)
    console.log("OWNER", owner.address)
    const OVixActions = await ethers.getContractFactory("OVixActions", owner);
    const oVixActions = await OVixActions.deploy();
    await oVixActions.deployed();

    await oVixActions.closePositions();

  });
});
