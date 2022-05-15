//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IOToken.sol";
import "../chainlink/IAggregatorV2V3.sol";

abstract contract PriceOracle {
  
    function getUnderlyingPrice(IOToken oToken) external virtual view returns (uint);

    function getFeed(address oToken) public virtual view returns (IAggregatorV2V3);
}
