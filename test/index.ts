import { expect } from "chai";
import { ethers, network } from "hardhat";
import { config } from 'dotenv'
import { IEIP20__factory } from "../typechain";
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
    const QUICKSWAP_ROUTER_POLYGON_MAINNET = '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff'

    const oVixActions = await OVixActions.deploy(POOL_ADDRESS_PROVIDER_POLYGON_MAINNET, QUICKSWAP_ROUTER_POLYGON_MAINNET);
    await oVixActions.deployed();

    const wbtc = IEIP20__factory.connect('0x3B9128Ddd834cE06A60B0eC31CCfB11582d8ee18', owner)
    const usdt = IEIP20__factory.connect('0x1372c34acC14F1E8644C72Dad82E3a21C211729f', owner)

    await wbtc.approve(oVixActions.address, ethers.constants.MaxUint256)
    await usdt.approve(oVixActions.address, ethers.constants.MaxUint256)
    
    await oVixActions.closePosition(wbtc.address, usdt.address);

  });
});
