//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IComptroller.sol";
import "../IEIP20.sol";

interface IOToken is IEIP20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function balanceOf(address user) external view returns (uint256);
    function balanceOfUnderlying(address owner) external returns (uint256);
    function borrowBalanceCurrent(address account) external returns (uint256);
    function borrowBalanceStored(address user) external view returns (uint256);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function exchangeRateStored() external view returns (uint);

    function mint(uint mintAmount) external;
    function redeem(uint redeemTokens) external;
    function redeemUnderlying(uint redeemAmount) external;
    function borrow(uint borrowAmount) external;
    function repayBorrow(uint repayAmount) external;
    function repayBorrowBehalf(address borrower, uint repayAmount) external;
    function liquidateBorrow(address borrower, uint repayAmount, IOToken oTokenCollateral) external;

    function underlying() external view returns(address);

    function comptroller() external view returns(IComptroller);
}
