//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./IOToken.sol";

contract OVixActions {
    IOToken private obtc = IOToken(0x3B9128Ddd834cE06A60B0eC31CCfB11582d8ee18);
    IOToken private ousdt = IOToken(0x1372c34acC14F1E8644C72Dad82E3a21C211729f);
    IOToken private ousdc = IOToken(0xEBb865Bf286e6eA8aBf5ac97e1b56A76530F3fBe);
    IOToken private omatic = IOToken(0xE554E874c9c60E45F1Debd479389C76230ae25A8);

    IOToken[4]  tokens = [obtc, ousdt, ousdc, omatic];

    modifier requireEmptyAfterOperation(){
        _;

        for (uint i = 0; i < tokens.length; i++) {
            
        }
    }

    function closePositions() public  {
        address sender = msg.sender;

        console.log("SENDER", sender);
        
        // create array of tokens
      
        
        for (uint i = 0; i < tokens.length; i++) {
            IOToken token = tokens[i];
            console.log("Borrowed", token.name(), token.borrowBalanceStored(sender));
            // get borrows
            // uint borrows = tokens[i].totalBorrows();
            // // for each borrow
            // for (uint j = 0; j < borrows; j++) {
            //     // get borrow
            //     uint borrow = tokens[i].borrow(j);
            //     // get borrow amount
            //     uint borrowAmount = borrow[0];
            //     // get borrow index
            //     uint borrowIndex = borrow[1];
            //     // get borrow address
            //     address borrower = borrow[2];
            //     // repay borrow
            //     tokens[i].repayBorrow(borrowAmount, borrower, borrowIndex);
            // }
        }

        //uint256 ousdtBalance = ousdt.repayBorrowBehalf(sender, 100);        

    }
}
