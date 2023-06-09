import { Address, Contract, ContractMethods, WaitForEventParams } from "locklift";
import { FactorySource, SellRootAbi } from "../../build/factorySource";

export class SellRoot {
  public contract: Contract<FactorySource["SellRoot"]>;
  public address: Address;
  public methods: ContractMethods<SellRootAbi>;

  constructor(contract: Contract<FactorySource["SellRoot"]>) {
    this.contract = contract;
    this.address = this.contract.address;
    this.methods = this.contract.methods;
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
