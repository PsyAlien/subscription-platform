// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract SubscriptionPlatform {

    // --- Structs ---
    struct SubscriptionService {
        address owner;       // Ägare av tjänsten
        uint price;          // Pris per period
        uint period;         // Längd på en period i sekunder
        bool paused;         // Om tjänsten är pausad
        uint balance;        // Insamlade intäkter
    }

    struct UserSubscription {
        uint expiry;         // Slutdatum för prenumerationen
    }

    // --- State ---
    mapping(uint => SubscriptionService) public services;        // ID => Tjänst
    mapping(uint => mapping(address => UserSubscription)) public subscriptions; // ServiceID => user => prenumeration
    uint public nextServiceId;

    // --- Events ---
    event ServiceCreated(uint serviceId, address owner, uint price, uint period);
    event Subscribed(uint serviceId, address user, uint expiry);
    event ServicePaused(uint serviceId);
    event ServiceResumed(uint serviceId);
    event SubscriptionGifted(uint serviceId, address from, address to);

    // --- Modifiers ---
    modifier onlyOwner(uint serviceId) {
        require(msg.sender == services[serviceId].owner, "Not service owner");
        _;
    }

    modifier serviceActive(uint serviceId) {
        require(!services[serviceId].paused, "Service is paused");
        _;
    }

    // --- Functions ---

    // Skapa en ny prenumerationstjänst
    function createService(uint _price, uint _period) external {
        services[nextServiceId] = SubscriptionService({
            owner: msg.sender,
            price: _price,
            period: _period,
            paused: false,
            balance: 0
        });

        emit ServiceCreated(nextServiceId, msg.sender, _price, _period);
        nextServiceId++;
    }


    // Prenumerera eller förläng prenumeration
function subscribe(uint serviceId) external payable serviceActive(serviceId) {
    SubscriptionService storage service = services[serviceId];
    require(msg.value >= service.price, "Insufficient payment");

    UserSubscription storage userSub = subscriptions[serviceId][msg.sender];

    // Om prenumerationen redan är aktiv, förläng den
    if (block.timestamp < userSub.expiry) {
        userSub.expiry += service.period;
    } else {
        // Ny prenumeration
        userSub.expiry = block.timestamp + service.period;
    }

    // Lägg pengarna i tjänstens balance
    service.balance += msg.value;

    emit Subscribed(serviceId, msg.sender, userSub.expiry);
}


// Kolla om en adress har en aktiv prenumeration
function isSubscribed(uint serviceId, address user) external view returns (bool) {
    return subscriptions[serviceId][user].expiry > block.timestamp;
}

// Hämta slutdatum för användarens prenumeration
function subscriptionExpiry(uint serviceId, address user) external view returns (uint) {
    return subscriptions[serviceId][user].expiry;
}


// --- Ägarfunktioner ---

// Pausa tjänsten
function pauseService(uint serviceId) external onlyOwner(serviceId) {
    SubscriptionService storage service = services[serviceId];
    service.paused = true;
    emit ServicePaused(serviceId);
}

// Återuppta tjänsten
function resumeService(uint serviceId) external onlyOwner(serviceId) {
    SubscriptionService storage service = services[serviceId];
    service.paused = false;
    emit ServiceResumed(serviceId);
}

// Ändra pris för tjänsten
function changePrice(uint serviceId, uint newPrice) external onlyOwner(serviceId) {
    services[serviceId].price = newPrice;
}

// Ta ut insamlade intäkter
function withdraw(uint serviceId) external onlyOwner(serviceId) {
    SubscriptionService storage service = services[serviceId];
    uint amount = service.balance;
    require(amount > 0, "No funds to withdraw");
    service.balance = 0;

    (bool sent, ) = service.owner.call{value: amount}("");
    require(sent, "Failed to send Ether");
}



// Ge bort prenumeration till en annan användare
function giftSubscription(uint serviceId, address to) external serviceActive(serviceId) {
    UserSubscription storage senderSub = subscriptions[serviceId][msg.sender];
    require(senderSub.expiry > block.timestamp, "You do not have an active subscription");

    UserSubscription storage recipientSub = subscriptions[serviceId][to];

    // Om mottagaren redan har aktiv prenumeration, lägg på tiden
    if (block.timestamp < recipientSub.expiry) {
        recipientSub.expiry += senderSub.expiry - block.timestamp;
    } else {
        recipientSub.expiry = block.timestamp + (senderSub.expiry - block.timestamp);
    }

    emit SubscriptionGifted(serviceId, msg.sender, to);
}


}
