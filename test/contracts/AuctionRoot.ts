import { Address, Contract, ContractMethods, WaitForEventParams } from "locklift";
import { FactorySource, AuctionRootAbi } from "../../build/factorySource";

export class AuctionRoot {
  public contract: Contract<FactorySource["AuctionRoot"]>;
  public address: Address;
  public methods: ContractMethods<AuctionRootAbi>;

  constructor(contract: Contract<FactorySource["AuctionRoot"]>) {
    this.contract = contract;
    this.address = this.contract.address;
    this.methods = this.contract.methods;
  }

  async changeExtraSeconds(value: number) {
    const keyPair = await locklift.keystore.getSigner("random");
    return this.methods.changeExtraSecondsAmount({ value }).sendExternal({ publicKey: keyPair.publicKey });
  }

  async getAucSettings() {
    return this.methods.getAuctionSettings({ answerId: 0 }).call();
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
