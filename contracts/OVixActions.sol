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

        uint256 fromBorrowed = from.borrowBalanceCurrent(account);
        //TokenBalance memory toBalance = getTokenBalances(to, account);

        POOL.flashLoanSimple(address(this), from.underlying(), fromBorrowed, abi.encode(from.underlying(), to.underlying()), 0);

        // TODO: send back tokens
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
        require(localBalance >= _amount, "Bad flashloan, bad bad bad");

        // PAY BACK BORROWED ASSETS
        require(fromAsset.approve(address(fromOToken), _amount), "Could not approve fromOToken");
        fromOToken.repayBorrowBehalf(account, _amount);
        require(fromOToken.borrowBalanceCurrent(account) == 0, "Did not paid loan back");

        uint256 totalFlashLoanAmountInFromAsset = _amount + _premium;
        uint256 amountToRedeemInAsset = _calculateRedeption(fromAsset, fromOToken, toAsset, toOToken, totalFlashLoanAmountInFromAsset);

        _redeem(toOToken, amountToRedeemInAsset);

        //swap(address(toAsset), address(fromAsset), totalFlashLoanAmountInToAsset, totalFlashLoanAmountInFromAsset, address(this));

        // Pay back the flashloan

        //fromAsset.transfer(_initiator, totalFlashLoanAmountInFromAsset);
        return true;
    }

    function _calculateRedeption(
        IEIP20 fromAsset,
        IOToken fromOToken,
        IEIP20 toAsset,
        IOToken toOToken,
        uint256 amountInFromAsset
    ) private view returns (uint256) {
        uint256 fromPrice = getPrice(fromOToken);
        uint256 toPrice = getPrice(toOToken);

        // console.log("totalFlashLoanAmountInFromAsset", amountInFromAsset); // 800989
        // console.log("From Price", fromPrice); //30223 653 00000 00000 00000
        // console.log("To Price", toPrice); // 0 998 76948 00000 00000

        // can be refactored to do one division less by just multiplying the delta decimals
        // TODO might be broken if the toAsset has less decimals
        //uint256 e18toFrom = 10**(18 - fromAsset.decimals());
        uint256 e18toTo = 10**(18 - toAsset.decimals());
        //console.log("e18toTo", e18toTo);

        uint256 valueInUSD = ((amountInFromAsset * fromPrice) / (10**fromAsset.decimals())); //amount of decimals from + price = 8 + 18 - 8 = 18
        //console.log('valueInUSD', valueInUSD);// USD with 18 decimals
        uint256 amountInToAsset = (valueInUSD * 1e18) / toPrice / e18toTo; // decimals 18 + 18 - 18 - 0= 18
        //console.log("totalFlashLoanAmountInToAsset", amountInToAsset);

        return amountInToAsset;
    }

    function _redeem(IOToken token, uint256 amountToRedeemInAsset) private returns (bool) {
        // console.log("oToken Decimals", token.decimals());
        // console.log("Exchange rate", token.exchangeRateStored());
        // console.log("Underlying", token.balanceOfUnderlying(account));

        // console.log("amountToRedeemInAsset", amountToRedeemInAsset); // 242386397
        // console.log("Account pre    ", token.balanceOf(address(account))); // 1206177100988
        // console.log("This    pre    ", token.balanceOf(address(this)));

        uint256 oTokensToTransfer = ((amountToRedeemInAsset * 1e18) / token.exchangeRateStored()); //
        // console.log("Transfer amount", oTokensToTransfer);
        require(token.transferFrom(account, address(this), oTokensToTransfer), "Could not transfer to0Tokens contract");

        // console.log("Account mid    ", token.balanceOf(address(account)));
        // console.log("This    mid    ", token.balanceOf(address(this)));

        token.redeemUnderlying(amountToRedeemInAsset);

        // console.log("Account post   ", token.balanceOf(address(account)));
        // console.log("This    post   ", token.balanceOf(address(this)));
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
            return uint256(answer) * (10**decimalDelta); // 99938371 * 1_00000_00000 = 00999_38371_00000_00000 => 0.999
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
