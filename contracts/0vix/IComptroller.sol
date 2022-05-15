//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./PriceOracle.sol";

interface IComptroller {
    function oracle() external view returns(PriceOracle);
    function getAllMarkets() external view returns(IOToken[] memory);
}
    