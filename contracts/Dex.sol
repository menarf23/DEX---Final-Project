// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./Wallet.sol";

contract Dex is Wallet {

    enum Side {
        BUY,
        SELL
    } // enum values are sort of integers in reality (0, 1, 2, etc.) i.e. BUY would be 0 and SELL would be 1

    struct Order {
        uint id; //order ID 
        address trader; // address of the actual trader that created the order
        Side tradingSide; // are you buying or selling
        bytes32 ticker; // what asset you want to buy or sell
        uint amount; // amount that user wants to buy or sell
        uint price; // at what price you want to buy or sell
        uint filled;
    }

    uint public nextOrderId = 0;

    // this double mapping is pointing from bytes32 "ticker" to uint of "tradingSide"(BUY or SELL, = 0 or 1) which is pointing to an array of Order structs
    // this way we basically get two orderbooks(buy and sell) for each assett(coin represented by ticker)
    mapping(bytes32 => mapping(uint => Order[])) public orderBook;

    function getOrderBook(bytes32 ticker, Side tradingSide) view public returns(Order[] memory) {
        return orderBook[ticker][uint(tradingSide)];
    }

    function createLimitOrder(Side tradingSide, bytes32 ticker, uint amount, uint price) public {
        if(tradingSide == Side.BUY){
            require(balances[msg.sender]["ETH"] >= amount*price);
        }

        if(tradingSide == Side.SELL){
            require(balances[msg.sender][ticker] >= amount);
        }

        // "orders" array is of storage memory type because it makes a reference to an array that is in the storage
        Order[] storage orders = orderBook[ticker][uint(tradingSide)]; // this is a list of orders for a specific ticker's buy or sell side
        // [Order1, Order2...]
        orders.push(
            Order(nextOrderId, msg.sender, tradingSide, ticker, amount, price, 0)
        );

        // Bubble sort
        // This can be done in multiple ways using while or for loop

        
        if(tradingSide == Side.BUY){
            
            Order memory temp_Buy_Order;
            for(uint i = orders.length-1; i > 0 ; i--){
                if (orders[i].price > orders[i-1].price){
                    temp_Buy_Order = orders[i];
                    orders[i] = orders[i-1];
                    orders[i-1] = temp_Buy_Order;
                }

                else{
                    break;
                }
            } 
        }


        else if (tradingSide == Side.SELL){
            
            Order memory temp_Sell_Order;
            for(uint i = orders.length-1; i > 0 ; i--){
                if (orders[i].price < orders[i-1].price){
                    temp_Sell_Order = orders[i];
                    orders[i] = orders[i-1];
                    orders[i-1] = temp_Sell_Order;
                }

                else{
                    break;
                }  
            }
        }

        nextOrderId++;
    }

    function createMarketOrder(Side tradingSide, bytes32 ticker, uint amount) public {
        if(tradingSide == Side.SELL){
            require(balances[msg.sender][ticker] >= amount, "Insufficient balance");
        }

        uint orderBookSide;
        if(tradingSide == Side.BUY){
            orderBookSide = 1; 
        } // this gets us orderbook for the opposite side of the market order placed above (i.e. SELL side in this case)

        else{
            orderBookSide = 0;
        } // this gets us orderbook for the opposite side of the market order placed above (i.e. BUY side in this case)

        Order[] storage orders = orderBook[ticker][orderBookSide];

        uint totalFilled = 0;

        // How much of the Market Order can we fill from the existing Limit Orders i.e. orders[i]
        for (uint256 i = 0; i < orders.length && totalFilled < amount; i++) {
            
            uint leftToFill = amount - totalFilled; //Market Order amount remaining to be filled
            uint availableToFill = orders[i].amount - orders[i].filled; //Limit Order amount available for filling the Market Order
            uint filledInThisRun = 0; //amount filled in the single loop iteration

            if(availableToFill > leftToFill){
                filledInThisRun = leftToFill; // Fill the entire market order
            }
            else{
                filledInThisRun = availableToFill; // Fill as much as it is available in orders[i]
            }

            // Update totalFilled
            totalFilled = totalFilled + filledInThisRun;
            orders[i].filled = orders[i].filled + filledInThisRun; //update the order after filling
            uint cost = filledInThisRun * orders[i].price;

            // Execute the trade & shift balances between buyer/seller
            // Verify that the buyer has enough ETH to cover the purchase (require) in this run
            if(tradingSide == Side.BUY){
                require(balances[msg.sender]["ETH"] >= cost);
                // msg.sender is the buyer
                // Transfer ETH from Buyer to Seller
                // Transfer Tokens from Seller to Buyer
                balances[msg.sender][ticker] = balances[msg.sender][ticker] + filledInThisRun;
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"] - cost;

                balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker] - filledInThisRun;
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"] + cost;
            }
            else if(tradingSide == Side.SELL){
                // msg.sender is the seller
                // Transfer ETH from Buyer to Seller
                // Transfer Tokens from Seller to Buyer
                balances[msg.sender][ticker] = balances[msg.sender][ticker] - filledInThisRun;
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"] + cost;

                balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker] + filledInThisRun;
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"] - cost;
            }
            
        }

        // Loop through the orderbook and remove 100% filled orders
        while(orders.length > 0 && orders[0].filled == orders[0].amount){
            // Remove the top element in the orders list by overwriting every element with the next element in the order list and then pop the last element out
            // This is not the best solution in terms of GAS consumption
            for (uint256 i = 0; i < orders.length - 1; i++) {
                orders[i] = orders[i+1];
            }
            orders.pop();
        }
    }
}