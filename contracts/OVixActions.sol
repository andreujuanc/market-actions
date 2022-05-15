//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "hardhat/console.sol";
import "./aave/IFlashLoanSimpleReceiver.sol";
import "./0vix/IOToken.sol";
import "./0vix/PriceOracle.sol";
import "./IEIP20.sol";
import "./core/Swap.sol";

contract OVixActions is Swap, IFlashLoanSimpleReceiver {
    // OVIX
    PriceOracle private priceOracle;
    IOToken private obtc = IOToken(0x3B9128Ddd834cE06A60B0eC31CCfB11582d8ee18);
    IOToken private ousdt = IOToken(0x1372c34acC14F1E8644C72Dad82E3a21C211729f);
    IOToken private ousdc = IOToken(0xEBb865Bf286e6eA8aBf5ac97e1b56A76530F3fBe);

    // NOt sure why ovix didnt use wmatic instead :/
    // IOToken private omatic =
    //     IOToken(0xE554E874c9c60E45F1Debd479389C76230ae25A8);

    IOToken[3] tokens = [obtc, ousdt, ousdc];
    mapping(address => IOToken) oTokens;
    mapping(address => IOToken) oTokensFromUnder;

    //AAVE
    IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
    IPool public immutable override POOL;

    constructor(IPoolAddressesProvider provider, address uniswapRouter) Swap(uniswapRouter) {
        for (uint256 i = 0; i < tokens.length; i++) {
            oTokens[address(tokens[i])] = tokens[i];
            oTokensFromUnder[tokens[i].underlying()] = tokens[i];
        }
        priceOracle = tokens[0].comptroller().oracle();

        // AAVE
        ADDRESSES_PROVIDER = provider;
        POOL = IPool(provider.getPool());
    }

    modifier requireEmptyAfterOperation() {
        _;

        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i].balanceOf(address(this)) == 0, "Contract cannot hold any balance after operation");
            // TODO: Require underlying asset to be 0 as well just in case
        }
    }

    address internal account = address(0);
    modifier nonReentrant(address account_) {
        require(account == (address(0)), "re-entered");
        account = account_;
        _;
        account = account_; // get a gas-refund post-Istanbul
    }

    function closePosition(address _from, address _to) public requireEmptyAfterOperation nonReentrant(msg.sender) {
        IOToken from = oTokens[_from];
        require(address(from) != address(0), "Invalid OVix token: from");

        IOToken to = oTokens[_to];
        require(address(to) != address(0), "Invalid OVix token: to");

        console.log("SENDER", account);

        console.log("Account TO pre", to.balanceOf(address(account)));
        console.log("This    TO pre", to.balanceOf(address(this)));

        require(to.transferFrom(account, address(this), 1), "Could not transfer to0Tokens to contract");
        //toOToken.redeemUnderlying(totalFlashLoanAmountInToAsset);

        console.log("Account TO pre", to.balanceOf(address(account)));
        console.log("This    TO pre", to.balanceOf(address(this)));

        //uint256 fromBorrowed = from.borrowBalanceCurrent(account);
        //TokenBalance memory toBalance = getTokenBalances(to, account);

        //POOL.flashLoanSimple(address(this), from.underlying(), fromBorrowed, abi.encode(from.underlying(), to.underlying()), 0);
        // get balances

        //uint256 ousdtBalance = ousdt.repayBorrowBehalf(sender, 100);
    }

    function executeOperation(
        address _asset,
        uint256 _amount,
        uint256 _premium,
        address _initiator,
        bytes calldata _params
    ) external returns (bool) {
        (address from, address to) = abi.decode(_params, (address, address));
        require(account != address(0), "Not initialized");
        require(from != address(0), "Invalid OVix token: from");
        require(to != address(0), "Invalid OVix token: to");
        require(msg.sender == address(POOL), "Only the flashloan pool can execute operations");
        require(_asset == from || _asset == to, "Invalid asset or callparams");

        IEIP20 fromAsset = IEIP20(from);
        IOToken fromOToken = oTokensFromUnder[from];

        IEIP20 toAsset = IEIP20(to);
        IOToken toOToken = oTokensFromUnder[to];

        uint256 localBalance = fromAsset.balanceOf(address(this));
        console.log("Got flash loan", _amount, _premium, _initiator);
        console.log("Local Balance", localBalance);
        require(localBalance >= _amount, "Bad flashloan, bad bad bad");

        // PAY BACK BORROWED ASSETS
        console.log("paying back", fromAsset.name(), _amount);
        require(fromAsset.approve(address(fromOToken), _amount), "Could not approve fromOToken");
        fromOToken.repayBorrowBehalf(account, _amount);
        console.log("PAID!");
        require(fromOToken.borrowBalanceCurrent(account) == 0, "Did not paid loan back");

        // We need to get part of the supply to pay the flashloan
        // Easiest is to transfer to this contract to redeem
        uint256 totalFlashLoanAmountInFromAsset = _amount + _premium;
        uint256 fromPrice = getPrice(fromOToken);
        uint256 toPrice = getPrice(toOToken);

        console.log("fromPrice", fromPrice);
        console.log("toPrice", toPrice);

        uint256 priceFromTo = (fromPrice * 1e18) / toPrice;
        console.log("priceFromTo", priceFromTo);

        uint256 totalFlashLoanAmountInToAsset = (totalFlashLoanAmountInFromAsset * priceFromTo) / 1e18;
        console.log("To redeem", totalFlashLoanAmountInToAsset);
        require(toOToken.transferFrom(account, address(this), toOToken.balanceOf(account)), "Could not transfer to oTokens to contract");
        //toOToken.redeemUnderlying(totalFlashLoanAmountInToAsset);

        console.log("TO", toAsset.balanceOf(address(this)));
        console.log("FROM", fromAsset.balanceOf(address(this)));

        require(toAsset.balanceOf(address(this)) >= totalFlashLoanAmountInToAsset, "Did not redeem");
        //swap(address(toAsset), address(fromAsset), totalFlashLoanAmountInToAsset, totalFlashLoanAmountInFromAsset, address(this));

        // Pay back the flashloan

        //fromAsset.transfer(_initiator, totalFlashLoanAmountInFromAsset);
        return true;
    }

    // function getTokenBalances(IOToken token) public returns (TokenBalance memory) {
    //     TokenBalance memory balances;

    //     balances.oTokenBalance = token.balanceOf(account);
    //     balances.borrowed = ;
    //     balances.underlying = token.balanceOfUnderlying(account);

    //     return balances;
    // }

    function getPrice(IOToken oToken) public view returns (uint256) {
        //uint price = priceOracle.getUnderlyingPrice(oToken);
        IAggregatorV2V3 feed = priceOracle.getFeed(address(oToken));
        uint256 decimalDelta = 18 - feed.decimals(); // 18-8 = 10

        (, int256 answer, , uint256 updatedAt, ) = feed.latestRoundData(); // answer = 99938371
        require(updatedAt > 0, "Round not complete");

        if (decimalDelta > 0) {
            return uint256(answer) * (10**decimalDelta); // 99938371 * 1_00000_00000 = 999_38371_00000_00000
        } else {
            return uint256(answer);
        }
    }

    struct TokenBalance {
        uint256 oTokenBalance;
        uint256 borrowed;
        uint256 underlying;
    }
}
