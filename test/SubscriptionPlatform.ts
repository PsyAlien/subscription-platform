import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("SubscriptionPlatform", function () {
  let platform: any;
  let owner: any, user1: any, user2: any;

  // ETH-pris och period som bigint
  const PRICE = 1n * 10n ** 18n; // 1 ETH
  const NEW_PRICE = 2n * 10n ** 18n; // 2 ETH
  const PERIOD = 60n * 60n * 24n * 30n; // 30 dagar i sekunder

  beforeEach(async () => {
    [owner, user1, user2] = await ethers.getSigners();

    // Hardhat 3: deploy returnerar redan contract instance
    const factory = await ethers.getContractFactory("SubscriptionPlatform", owner);
    platform = await factory.deploy();
  });

  it("should create a new service", async () => {
    await expect(platform.connect(owner).createService(PRICE, PERIOD))
      .to.emit(platform, "ServiceCreated")
      .withArgs(0, owner.address, PRICE, PERIOD);

    const service = await platform.services(0);
    expect(service.owner).to.equal(owner.address);
    expect(service.price).to.equal(PRICE);
    expect(service.period).to.equal(PERIOD);
    expect(service.paused).to.equal(false);
    expect(service.balance).to.equal(0n);
  });

  it("should allow a user to subscribe and extend subscription", async () => {
    await platform.connect(owner).createService(PRICE, PERIOD);

    // Prenumerera första gången
    await expect(platform.connect(user1).subscribe(0, { value: PRICE }))
      .to.emit(platform, "Subscribed");

    let sub = await platform.subscriptions(0, user1.address);
    expect(sub.expiry).to.be.greaterThan(0n);

    // Förläng prenumeration
    const oldExpiry = sub.expiry;
    await platform.connect(user1).subscribe(0, { value: PRICE });
    sub = await platform.subscriptions(0, user1.address);
    expect(sub.expiry).to.be.greaterThan(oldExpiry);
  });

  it("should correctly report subscription status", async () => {
    await platform.connect(owner).createService(PRICE, PERIOD);

    expect(await platform.isSubscribed(0, user1.address)).to.equal(false);

    await platform.connect(user1).subscribe(0, { value: PRICE });
    expect(await platform.isSubscribed(0, user1.address)).to.equal(true);
  });

  it("should pause and resume a service", async () => {
    await platform.connect(owner).createService(PRICE, PERIOD);

    await expect(platform.connect(owner).pauseService(0))
      .to.emit(platform, "ServicePaused");
    let service = await platform.services(0);
    expect(service.paused).to.equal(true);

    await expect(platform.connect(owner).resumeService(0))
      .to.emit(platform, "ServiceResumed");
    service = await platform.services(0);
    expect(service.paused).to.equal(false);
  });

  it("should allow owner to change price and withdraw funds", async () => {
    await platform.connect(owner).createService(PRICE, PERIOD);

    await platform.connect(user1).subscribe(0, { value: PRICE });
    let service = await platform.services(0);
    expect(service.balance).to.equal(PRICE);

    await platform.connect(owner).changePrice(0, NEW_PRICE);
    service = await platform.services(0);
    expect(service.price).to.equal(NEW_PRICE);

    const ownerBalanceBefore = await owner.getBalance();
    const tx = await platform.connect(owner).withdraw(0);
    const receipt = await tx.wait();
    const gasUsed = receipt.gasUsed * receipt.effectiveGasPrice; // bigint

    const ownerBalanceAfter = await owner.getBalance();
    expect(ownerBalanceAfter - ownerBalanceBefore + gasUsed).to.equal(PRICE);

    service = await platform.services(0);
    expect(service.balance).to.equal(0n);
  });

  it("should allow gifting a subscription to another user", async () => {
    await platform.connect(owner).createService(PRICE, PERIOD);

    await platform.connect(user1).subscribe(0, { value: PRICE });
    const senderSub = await platform.subscriptions(0, user1.address);

    await expect(platform.connect(user1).giftSubscription(0, user2.address))
      .to.emit(platform, "SubscriptionGifted");

    const recipientSub = await platform.subscriptions(0, user2.address);
    expect(recipientSub.expiry).to.equal(senderSub.expiry);
  });

  it("should prevent non-owners from pausing or withdrawing", async () => {
    await platform.connect(owner).createService(PRICE, PERIOD);

    await expect(platform.connect(user1).pauseService(0)).to.be.revertedWith("Not service owner");
    await expect(platform.connect(user1).withdraw(0)).to.be.revertedWith("Not service owner");
  });
});
