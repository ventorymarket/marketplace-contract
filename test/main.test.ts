const chai = require("chai");
const assertArrays = require("chai-arrays");
chai.use(assertArrays);
const expect = chai.expect;

const { TonClient } = require("@tonclient/core");
const { libNode } = require("@tonclient/lib-node");
import { SimpleKeystore } from "everscale-standalone-client/nodejs";
import { zeroAddress, Signer, Address } from "locklift";
import { Account } from "locklift/internal/factory";
import { FactorySource } from "../build/factorySource";
import { Collection } from "./contracts/Collection";
import { SellRoot } from "./contracts/SellRoot";
import { Nft } from "./contracts/Nft";
import { Sell } from "./contracts/Sell";
import { AuctionRoot } from "./contracts/AuctionRoot";
import { Auction } from "./contracts/Auction";

const { add0x, sleep } = require("@growth-driver/everscale-contracts-tip4/utils/utils");

TonClient.useBinaryLibrary(libNode);

describe("Deploy main contracts, test all getters and setters on SellRoot, test sell and auction", () => {
  let client;

  let nftRoot: Collection;
  let keyPair: Signer;

  let sellRoot: SellRoot;
  let secondSellRootKeys: Signer;

  let auctionRoot: AuctionRoot;
  let auctionOfferAcc: Auction;

  let sellRootAddr;
  let auctionRootAddr;

  let wallets: Account<FactorySource["Wallet"]>[] = [];
  let walletsKeys: Signer[] = [];

  let nftAcc: Nft;
  let nftAddress;

  let sellOfferAddress;

  let auctionOfferAddress;
  let secondAuctionOfferAddress;
  let thirdAuctionOfferAddress;
  let currentAuctionBidValue;
  let nextAuctionBidValue;
  let thirdAuctionEndTime;

  before(async () => {
    client = new TonClient({
      network: {
        endpoints: locklift.context.network.config.connection.data.endpoints,
      },
    });
  });

  after(async () => {
    client.close();
  });

  it("Deploy NftRoot contract", async () => {
    const randKeyPair = SimpleKeystore.generateKeyPair();
    await locklift.keystore.addKeyPair("random", randKeyPair);
    keyPair = await locklift.keystore.getSigner("random");

    const nftArtifacts = await locklift.factory.getContractArtifacts("Nft");
    const indexArtifacts = await locklift.factory.getContractArtifacts("Index");
    const indexBasisArtifacts = await locklift.factory.getContractArtifacts("IndexBasis");

    const { contract: nftRootContract } = await locklift.tracing.trace(
      locklift.factory.deployContract({
        contract: "CollectionSample",
        publicKey: keyPair.publicKey,
        initParams: {},
        constructorParams: {
          codeNft: nftArtifacts.code,
          codeIndex: indexArtifacts.code,
          codeIndexBasis: indexBasisArtifacts.code,
          ownerPubkey: add0x(keyPair.publicKey),
          json: "{}",
          mintingFee: locklift.utils.toNano(2),
          withdrawalAddress: zeroAddress,
        },
        value: locklift.utils.toNano(10),
      }),
    );
    nftRoot = new Collection(nftRootContract);

    console.log(`Nft root address: ${nftRoot.address.toString()}`);
    const res = await checkAccountStatus(nftRoot.address.toString());
    expect(1).to.be.equal(res.acc_type);
  });

  it("Create multisigs", async () => {
    for (let i = 0; i < 3; i++) {
      await locklift.keystore.addKeyPair(`wallet${i}`, SimpleKeystore.generateKeyPair());
      const keyPair = await locklift.keystore.getSigner(`wallet${i}`);
      let accountsFactory = await locklift.factory.getAccountsFactory("Wallet");
      const { account: account } = await accountsFactory.deployNewAccount({
        publicKey: keyPair.publicKey,
        initParams: {
          _randomNonce: locklift.utils.getRandomNonce(),
        },
        constructorParams: {},
        value: locklift.utils.toNano(10000),
      });

      wallets.push(account);
      walletsKeys.push(keyPair);
      console.log(`Wallet${i} address: ${account.address.toString()}`);
    }
  });

  it("Deploy SellRoot contract", async () => {
    const offerArtifacts = await locklift.factory.getContractArtifacts("Sell");
    const { contract: sellRootContract } = await locklift.tracing.trace(
      locklift.factory.deployContract({
        contract: "SellRoot",
        publicKey: keyPair.publicKey,
        initParams: {},
        constructorParams: {
          ownerPubkey: add0x(keyPair.publicKey),
          offerCode: offerArtifacts.code,
          deploymentFee: locklift.utils.toNano(1),
          creationPrice: locklift.utils.toNano(1),
          nftGasAmount: locklift.utils.toNano(0.5),
          minimalGasAmount: locklift.utils.toNano(0.2),
          leftOnOfferAfterFinish: locklift.utils.toNano(0.01),
          nftTransferFee: locklift.utils.toNano(1.1),
          methodsCallsFee: locklift.utils.toNano(0.1),
          marketFee: 3,
          marketFeeDecimals: 0,
          withdrawalAddress: wallets[0].address,
        },
        value: locklift.utils.toNano(10),
      }),
    );
    sellRoot = new SellRoot(sellRootContract);

    sellRootAddr = await sellRoot.address.toString();

    console.log(`Sell root address: ${sellRootAddr}}`);
    const res = await checkAccountStatus(sellRootAddr);
    expect(1).to.be.equal(res.acc_type);
  });

  it.skip("Change owner", async () => {
    await locklift.keystore.addKeyPair("secondSellRootKeys", SimpleKeystore.generateKeyPair());
    secondSellRootKeys = await locklift.keystore.getSigner("secondSellRootKeys");
    await sellRoot.methods
      .changeOwner({
        owner: add0x(secondSellRootKeys.publicKey),
      })
      .sendExternal({ publicKey: keyPair.publicKey });

    await sleep(1000);

    const owner = (
      await sellRoot.methods
        .getOwner({
          answerId: 0,
        })
        .call()
    ).ownerPubkey;

    expect(add0x(secondSellRootKeys.publicKey)).to.be.equal(owner);
  });

  it.skip("Change owner pubkey back", async () => {
    await sellRoot.methods
      .changeOwner({
        owner: add0x(keyPair.publicKey),
      })
      .sendExternal({
        publicKey: secondSellRootKeys.publicKey,
      });

    await sleep(1000);

    const owner = (
      await sellRoot.methods
        .getOwner({
          answerId: 0,
        })
        .call()
    ).ownerPubkey;

    expect(owner).to.be.equal(add0x(keyPair.publicKey));
  });

  it("Change SellRoot fees", async () => {
    const deploymentFeeValue = locklift.utils.toNano(1.5),
      marketFeeValue = 5,
      creationPriceValue = locklift.utils.toNano(0.3);

    await sellRoot.methods
      .setDeploymentFee({
        value: deploymentFeeValue,
      })
      .sendExternal({ publicKey: keyPair.publicKey });

    await sellRoot.methods
      .setMarketFee({
        value: marketFeeValue,
        decimals: 0,
      })
      .sendExternal({ publicKey: keyPair.publicKey });

    await sellRoot.methods
      .setCreationPrice({
        value: creationPriceValue,
      })
      .sendExternal({ publicKey: keyPair.publicKey });

    await sleep(1000);

    const fees = await sellRoot.methods
      .getFeesInfo({
        answerId: 0,
      })
      .call();

    expect(fees.deploymentFee).to.be.equal(deploymentFeeValue);
    expect(+fees.marketFee).to.be.equal(marketFeeValue);
    expect(fees.creationPrice).to.be.equal(creationPriceValue);
  });

  it("Change withdrawal address", async () => {
    await wallets[0].runTarget(
      {
        contract: sellRoot.contract,
        value: locklift.utils.toNano(0.1),
      },
      sellRoot =>
        sellRoot.methods.changeWithdrawalAddress({
          newAddress: wallets[1].address,
        }),
    );

    await sleep(1000);

    const newWithdrawalAddress = (
      await sellRoot.methods
        .getWithdrawalAddress({
          answerId: 0,
        })
        .call()
    ).withdrawalAddress;

    expect(await wallets[1].address.toString()).to.be.equal(newWithdrawalAddress.toString());
  });

  it("Mint 1 item", async () => {
    await wallets[0].runTarget(
      {
        contract: nftRoot.contract,
        value: locklift.utils.toNano(4),
      },
      nftRoot =>
        nftRoot.methods.mint({
          json: "{}",
          royalty: [[zeroAddress, 10]],
        }),
    );

    const event = (await nftRoot.getLastEvent("NftCreated")) as any;
    const nftContract = await locklift.factory.getDeployedContract("Nft", new Address(event.nft.toString()));
    nftAcc = new Nft(nftContract);
    nftAddress = event.nft;

    console.log(`NFT address: ${nftAddress}`);
  });

  it("Put on sell", async () => {
    await deploySellOffer(wallets[0]);

    const event = await sellRoot.getLastEvent("SellDeployed");
    let managerAddress;
    managerAddress = (await nftAcc.getInfo()).manager;
    sellOfferAddress = event.offerInfo.offer;

    await sleep(1000);

    expect(1).to.be.equal((await checkAccountStatus(sellOfferAddress)).acc_type);
    expect(sellOfferAddress.toString()).to.be.equal(managerAddress.toString());
  });

  it("Test offer getters (code, codehash, address)", async () => {
    const code = (
      await sellRoot.methods
        .offerCode({
          answerId: 0,
        })
        .call()
    ).code;

    const codeHash = (
      await sellRoot.methods
        .offerCodeHash({
          answerId: 0,
        })
        .call()
    ).codeHash;

    const address = (
      await sellRoot.methods
        .offerAddress({
          answerId: 0,
          id: 1,
        })
        .call()
    ).offer;

    const offerContract = await locklift.factory.getDeployedContract("Sell", sellOfferAddress);
    const offerState = await offerContract.getFullState();
    // expect(code).to.be.equal(offerState.state.boc);
    // expect(codeHash).to.be.equal(offerState.state.codeHash);
    expect(sellOfferAddress.toString()).to.be.equal(address.toString());
  });

  it("Check sell offer fees values", async () => {
    const offerContract = await locklift.factory.getDeployedContract("Sell", sellOfferAddress);

    const price = locklift.utils.toNano(1);
    const fees = await offerContract.methods
      .getFeesValues({
        answerId: 0,
      })
      .call();

    const marketFeeValue = (+price / 100) * 5,
      royaltyValue = (+price / 100) * 10;

    expect(+fees.totalFeeValue).to.be.equal(marketFeeValue + royaltyValue);
    expect(+fees.marketFeeValue).to.be.equal(marketFeeValue);
    // expect(+fees.royalties[zeroAddress.toString()]).to.be.equal(royaltyValue);
  });

  it("Buy NFT", async () => {
    await wallets[1].transfer({ recipient: sellOfferAddress, value: locklift.utils.toNano(2) });

    await sleep(1000);

    const event = await sellRoot.getLastEvent("SellConfirmed");
    const newOwnerAddress = wallets[1].address.toString();
    const nftInfo = await nftAcc.getInfo();

    expect(nftInfo.owner.toString()).to.be.equal(newOwnerAddress.toString());
    expect(nftInfo.manager.toString()).to.be.equal(newOwnerAddress.toString());
  });

  it("Put on sell with zero price", async () => {
    await deploySellOffer(wallets[1], { price: '0' });

    const event = await sellRoot.waitForEvent("SellRejected");
    const info = await nftAcc.getInfo();

    expect(event.addrNft.toString()).to.be.equal(nftAddress.toString());
    expect(wallets[1].address.toString()).to.be.equal(info.manager.toString());
  });

  it("Deploy another offer and cancel it", async () => {
    await deploySellOffer(wallets[1]);

    const deployedEvent = await sellRoot.getLastEvent("SellDeployed");
    const offerAdress = deployedEvent.offerInfo.offer;

    const offerAccount = await Sell.fromAddr(offerAdress);
    await offerAccount.cancelOrder(wallets[1]);

    const cancelledEvent = await sellRoot.getLastEvent("SellCancelled");
    let managerAddress = (await nftAcc.getInfo()).manager;

    expect(3).to.be.equal((await checkAccountStatus(offerAdress.toString())).acc_type);
    expect(wallets[1].address.toString()).to.be.equal(managerAddress.toString());
  });

  it("Deploy AuctionRoot contract", async () => {
    const offerArtifacts = await locklift.factory.getContractArtifacts("Auction");
    const { contract: auctionRootContract } = await locklift.tracing.trace(
      locklift.factory.deployContract({
        contract: "AuctionRoot",
        publicKey: keyPair.publicKey,
        initParams: {},
        constructorParams: {
          ownerPubkey: add0x(keyPair.publicKey),
          offerCode: offerArtifacts.code,
          deploymentFee: locklift.utils.toNano(1.5),
          creationPrice: locklift.utils.toNano(0.3),
          nftGasAmount: locklift.utils.toNano(0.5),
          minimalGasAmount: locklift.utils.toNano(0.2),
          leftOnOfferAfterFinish: locklift.utils.toNano(0.01),
          nftTransferFee: locklift.utils.toNano(1.1),
          methodsCallsFee: locklift.utils.toNano(0.1),
          marketFee: 3,
          marketFeeDecimals: 0,
          withdrawalAddress: wallets[0].address,
          auctionBidDelta: 10,
          extraSecondsAmount: 0,
        },
        value: locklift.utils.toNano(10),
      }),
    );

    auctionRoot = new AuctionRoot(auctionRootContract);
    auctionRootAddr = auctionRoot.address;

    const res = await checkAccountStatus(auctionRootAddr.toString());
    expect(1).to.be.equal(res.acc_type);
  });

  it("Put on auction", async () => {
    await deployAuctionOffer(wallets[1], { price: locklift.utils.toNano(1), auctionDuration: 20 });
    const event = await auctionRoot.getLastEvent("AuctionDeployed");
    auctionOfferAddress = event.offerInfo.offer;
    auctionOfferAcc = await Auction.fromAddr(auctionOfferAddress);

    await sleep(1000);

    let managerAddress = (await nftAcc.getInfo()).manager.toString();

    expect(1).to.be.equal((await checkAccountStatus(auctionOfferAddress.toString())).acc_type);
    expect(auctionOfferAddress.toString()).to.be.equal(managerAddress);
  });

  it("Place first bid", async () => {
    currentAuctionBidValue = locklift.utils.toNano(1);
    nextAuctionBidValue = +locklift.utils.toNano(1) + (+locklift.utils.toNano(1) / 100) * 10;

    await wallets[0].transfer({ recipient: auctionOfferAddress, value: currentAuctionBidValue, flags: 3 });
    const event = await auctionOfferAcc.getLastEvent("BidPlaced");
    await sleep(1000);

    const aucInfo = await auctionOfferAcc.getInfo();
  
    expect(currentAuctionBidValue).to.be.equal(aucInfo.currentBidValue);
    expect(nextAuctionBidValue).to.be.equal(+aucInfo.nexBidValue);
    expect(wallets[0].address.toString()).to.be.equal(aucInfo.currentBidAddress.toString());
  });

  it("Place second bid", async () => {
    currentAuctionBidValue = nextAuctionBidValue;
    nextAuctionBidValue = currentAuctionBidValue + (currentAuctionBidValue / 100) * 10;

    await wallets[2].transfer({ recipient: auctionOfferAddress, value: currentAuctionBidValue, flags: 3});

    await sleep(1000);

    const aucInfo = await auctionOfferAcc.getInfo();

    expect(currentAuctionBidValue).to.be.equal(+aucInfo.currentBidValue);
    expect(nextAuctionBidValue).to.be.equal(+aucInfo.nexBidValue);
    expect(wallets[2].address.toString()).to.be.equal(aucInfo.currentBidAddress.toString());
  });

  it("Place bid lower than required", async () => {
    await wallets[0].transfer({
      recipient: auctionOfferAddress,
      value: currentAuctionBidValue,
      flags: 3
    });

    await sleep(1000);

    const aucInfo = await auctionOfferAcc.getInfo();

    expect(currentAuctionBidValue).to.be.equal(+aucInfo.currentBidValue);
    expect(nextAuctionBidValue).to.be.equal(+aucInfo.nexBidValue);
    expect(wallets[2].address.toString()).to.be.equal(aucInfo.currentBidAddress.toString());
  });

  it("Finish auction", async () => {
    await sleep(20000);

    await auctionOfferAcc.finish();

    await sleep(1000);

    const rootEvent = await auctionRoot.getLastEvent("AuctionFinished");
    const offerEvent = await auctionOfferAcc.getLastEvent("AuctionFinished");

    const newOwnerAddress = wallets[2].address.toString();
    const nftInfo = await nftAcc.getInfo();

    expect(nftInfo.owner.toString()).to.be.equal(newOwnerAddress);
    expect(nftInfo.manager.toString()).to.be.equal(newOwnerAddress);
  });

  it("Put on auction to test the expiration", async () => {
    await deployAuctionOffer(wallets[2], { price: locklift.utils.toNano(1), auctionDuration: 2 });

    const event = await auctionRoot.getLastEvent("AuctionDeployed");
    secondAuctionOfferAddress = event.offerInfo.offer;
    const managerAddress = (await nftAcc.getInfo()).manager.toString();

    // Wait for the offer account deployment
    await sleep(1000);

    expect(1).to.be.equal((await checkAccountStatus(secondAuctionOfferAddress.toString())).acc_type);
    expect(secondAuctionOfferAddress.toString()).to.be.equal(managerAddress);
  });

  it("Finish expired auction without bids", async () => {
    await sleep(1000);
    const aucAcc = await Auction.fromAddr(secondAuctionOfferAddress);
    await aucAcc.finish();

    await sleep(1000);

    const rootEvent = await auctionRoot.getLastEvent("AuctionExpired");

    const ownerAddress = wallets[2].address.toString();
    const nftInfo = await nftAcc.getInfo();

    expect(nftInfo.owner.toString()).to.be.equal(ownerAddress);
    expect(nftInfo.manager.toString()).to.be.equal(ownerAddress);
  });

  it("Change aucs exta seconds amount", async () => {
    const newExtaSecondsAmount = 5;
  
    await auctionRoot.changeExtraSeconds(newExtaSecondsAmount);
    await sleep(1000);

    const extraSecondsAmount = (await auctionRoot.getAucSettings()).extraSecondsAmount;

    expect(parseInt(extraSecondsAmount, 16)).to.be.equal(newExtaSecondsAmount);
  });

  it("Deploy new auction to test extra seconds addition", async () => {
    await deployAuctionOffer(wallets[2], { price: locklift.utils.toNano(1), auctionDuration: 10 });

    const event = await auctionRoot.getLastEvent("AuctionDeployed");

    thirdAuctionOfferAddress = event.offerInfo.offer;
    currentAuctionBidValue = locklift.utils.toNano(1);

    thirdAuctionEndTime = (await (await Auction.fromAddr(thirdAuctionOfferAddress)).getInfo()).auctionEndTime;
    console.log(`${thirdAuctionEndTime}, ${parseInt(thirdAuctionEndTime, 16)}`)

    expect(1).to.be.equal((await checkAccountStatus(thirdAuctionOfferAddress.toString())).acc_type);
  });

  it("Put bid that should increase auction end time", async () => {
    await sleep(6000);

    await wallets[0].transfer({
      recipient: thirdAuctionOfferAddress,
      value: currentAuctionBidValue,
      flags: 3
    });

    await sleep(1000);
    const info = await (await Auction.fromAddr(thirdAuctionOfferAddress)).getInfo();
    console.log(thirdAuctionOfferAddress)
    console.log(info)
    const auctionEndTime = info.auctionEndTime;

    expect(+auctionEndTime).to.be.equal(+thirdAuctionEndTime + 5);
  });

  async function deploySellOffer(wallet: Account<FactorySource["Wallet"]>, params = { price: locklift.utils.toNano(1) }) {
    const payload = (
      await sellRoot.methods
        .generatePayload({
          answerId: 0,
          ...params,
        })
        .call()
    ).payload;

    return nftAcc.changeManager(wallet, sellRoot.address, [
      [
        sellRoot.address,
        {
          value: locklift.utils.toNano(2),
          payload,
        },
      ],
    ]);
  }

  async function deployAuctionOffer(
    wallet: Account<FactorySource["Wallet"]>,
    params = { price: locklift.utils.toNano(1), auctionDuration: 20 },
  ) {
    const payload = (
      await auctionRoot.methods
        .generatePayload({
          answerId: 0,
          ...params,
        })
        .call()
    ).payload;

    return nftAcc.changeManager(wallet, auctionRoot.address, [
      [
        auctionRoot.address,
        {
          value: locklift.utils.toNano(2),
          payload,
        },
      ],
    ]);
  }

  async function checkAccountStatus(address) {
    return (
      await client.net.query_collection({
        collection: "accounts",
        filter: {
          id: { eq: address },
        },
        result: "acc_type",
      })
    ).result[0];
  }
});
