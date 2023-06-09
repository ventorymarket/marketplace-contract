import { Address, Contract, ContractMethods } from "locklift";
import { FactorySource, AuctionAbi } from "../../build/factorySource";
import { Account } from "locklift/internal/factory";

export class Auction {
  public contract: Contract<FactorySource["Auction"]>;
  public address: Address;
  public methods: ContractMethods<AuctionAbi>;

  constructor(contract: Contract<FactorySource["Auction"]>) {
    this.contract = contract;
    this.address = this.contract.address;
    this.methods = this.contract.methods;
  }

  static async fromAddr(addr: Address) {
    return new Auction(await locklift.factory.getDeployedContract("Auction", addr));
  }

  async finish() {
    const keyPair = await locklift.keystore.getSigner("random");
    return this.methods.finishAuction().sendExternal({ publicKey: keyPair.publicKey });
  }

  async getInfo() {
    return this.contract.methods.getAuctionInfo({ answerId: 0 }).call();
  }

  async getEvents(eventName: string) {
    return (await this.contract.getPastEvents({ filter: event => event.event === eventName })).events;
  }

  async getLastEvent(eventName: string) {
    const lastEvent = (await this.getEvents(eventName)).shift();

    return lastEvent?.data;
  }

  async waitForEvent(eventName: string) {
    return (await this.contract.waitForEvent({ filter: event => event.event === eventName })).data;
  }
}
