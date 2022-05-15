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

    const POOL_ADDRESS_PROVIDER_POLYGON_MAINNET = '0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb'
    const oVixActions = await OVixActions.deploy(POOL_ADDRESS_PROVIDER_POLYGON_MAINNET); // p
    await oVixActions.deployed();

    // BTC > USDT
    await oVixActions.closePosition('0x3B9128Ddd834cE06A60B0eC31CCfB11582d8ee18', '0x1372c34acC14F1E8644C72Dad82E3a21C211729f');

  });
});
