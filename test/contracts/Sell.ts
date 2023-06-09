import { Address, Contract, ContractMethods } from "locklift";
import { FactorySource, SellAbi } from "../../build/factorySource";
import { Account } from "locklift/internal/factory";

export class Sell {
  public contract: Contract<FactorySource["Sell"]>;
  public address: Address;
  public methods: ContractMethods<SellAbi>;

  constructor(contract: Contract<FactorySource["Sell"]>) {
    this.contract = contract;
    this.address = this.contract.address;
    this.methods = this.contract.methods;
  }

  static async fromAddr(addr: Address) {
    return new Sell(await locklift.factory.getDeployedContract("Sell", addr));
  }

  async cancelOrder(initiator: Account<FactorySource["Wallet"]>) {
    return initiator.runTarget(
      {
        contract: this.contract,
        value: locklift.utils.toNano(1),
        flags: 1,
      },
      sell => sell.methods.cancelOrder({}),
    );
  }

  async getEvents(eventName: string) {
    return (await this.contract.getPastEvents({ filter: event => event.event === eventName })).events;
  }

  async getLastEvent(eventName: string) {
    const lastEvent = (await this.getEvents(eventName)).shift();

    return lastEvent?.data;
  }
}
