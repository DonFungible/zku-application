// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract Purchase {
    uint256 public value;
    address payable public seller;
    address payable public buyer;
    uint256 public purchaseTime;

    enum State {
        Created,
        Locked,
        Inactive
    }
    // The state variable has a default value of the first member, `State.created`
    State public state;

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    /// Only the buyer can call this function.
    error OnlyBuyer();
    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();
    /// Is not owner OR 5 minutes has not elapsed after buyer confirmed received
    error OnlyBuyerOr5MinutesAfterPurchase();

    modifier onlyBuyer() {
        if (msg.sender != buyer) revert OnlyBuyer();
        _;
    }

    modifier onlyBuyerOr5MinutesAfterPurchase() {
        bool isBuyer = (msg.sender == buyer);
        bool is5MinutesAfterPurchase = (block.timestamp - purchaseTime >
            5 * 60);

        if (!isBuyer && !is5MinutesAfterPurchase) {
            revert OnlyBuyerOr5MinutesAfterPurchase();
        }
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller) revert OnlySeller();
        _;
    }

    modifier inState(State state_) {
        if (state != state_) revert InvalidState();
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    event BuyerRefunded();
    event SellerRefunded();

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        seller = payable(msg.sender);
        value = msg.value / 2;
        if ((2 * value) != msg.value) revert ValueNotEven();
    }

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
    function abort() external onlySeller inState(State.Created) {
        emit Aborted();
        state = State.Inactive;
        // We use transfer here directly. It is
        // reentrancy-safe, because it is the
        // last call in this function and we
        // already changed the state.
        seller.transfer(address(this).balance);
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase()
        external
        payable
        inState(State.Created)
        condition(msg.value == (2 * value))
    {
        emit PurchaseConfirmed();
        buyer = payable(msg.sender);
        state = State.Locked;
        purchaseTime = block.timestamp;
    }

    /// Buyer or seller (after 5 minutes of purchase confirmation) can complete the purchase and both parties get refunded
    function completePurchase()
        external
        inState(State.Locked)
        onlyBuyerOr5MinutesAfterPurchase
    {
        state = State.Inactive; // Prevent reentrancy

        emit BuyerRefunded();
        buyer.transfer(value);

        emit SellerRefunded();
        seller.transfer(3 * value);
    }
}
