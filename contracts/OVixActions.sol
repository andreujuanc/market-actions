//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "hardhat/console.sol";
import "./aave/IFlashLoanSimpleReceiver.sol";
import "./IOToken.sol";
import "./IEIP20.sol";

contract OVixActions is IFlashLoanSimpleReceiver {
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

    constructor(IPoolAddressesProvider provider) {
        for (uint256 i = 0; i < tokens.length; i++) {
            oTokens[address(tokens[i])] = tokens[i];
            oTokensFromUnder[tokens[i].underlying()] = tokens[i];
        }

        // AAVE
        ADDRESSES_PROVIDER = provider;
        POOL = IPool(provider.getPool());
    }

    modifier requireEmptyAfterOperation() {
        _;

        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i].balanceOf(address(this)) == 0);
            // TODO: Require underlying asset to be 0 as well just in case
        }
    }

    bool internal _notEntered = true;
    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }

    function closePosition(address _from, address _to)
        public
        requireEmptyAfterOperation
        nonReentrant
    {
        address account = msg.sender;

        IOToken from = oTokens[_from];
        require(address(from) != address(0), "Invalid OVix token: from");

        IOToken to = oTokens[_to];
        require(address(to) != address(0), "Invalid OVix token: to");

        console.log("SENDER", account);

        TokenBalance memory fromBalance = getTokenBalances(from, account);
        TokenBalance memory toBalance = getTokenBalances(to, account);

        POOL.flashLoanSimple(
            address(this),
            from.underlying(),
            fromBalance.borrowed,
            new bytes(0),
            0
        );
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
        IEIP20 asset = IEIP20(_asset);
        IOToken oToken = oTokensFromUnder[_asset];

        uint256 localBalance = asset.balanceOf(address(this));
        console.log("Got flash loan", _amount, _premium, _initiator);
        console.log("Local Balance", localBalance);
        require(localBalance >= _amount, "Bad flashloan, bad bad bad");

        // swap the tokens

        // payback
        uint256 total = _amount + _premium;
        asset.transfer(_initiator, total);
        return true;
    }

    function getTokenBalances(IOToken token, address account)
        public
        returns (TokenBalance memory)
    {
        TokenBalance memory balances;

        balances.oTokenBalance = token.balanceOf(account);
        balances.borrowed = token.borrowBalanceCurrent(account);
        balances.underlying = token.balanceOfUnderlying(account);

        return balances;
    }

    struct TokenBalance {
        uint256 oTokenBalance;
        uint256 borrowed;
        uint256 underlying;
    }
}
