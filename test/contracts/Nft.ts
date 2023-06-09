import { Address, Contract, ContractMethods } from "locklift";
import { FactorySource, NftAbi } from "../../build/factorySource";
import { Account } from "locklift/internal/factory";

export type CallbackType = [
  Address,
  {
    value: string | number;
  } & {
    payload: string;
  },
];

export class Nft {
  public contract: Contract<FactorySource["Nft"]>;
  public address: Address;
  public methods: ContractMethods<NftAbi>;

  constructor(contract: Contract<FactorySource["Nft"]>) {
    this.contract = contract;
    this.address = this.contract.address;
    this.methods = this.contract.methods;
  }

  async getInfo() {
    return this.contract.methods.getInfo({ answerId: 0 }).call();
  }

  async changeManager(initiator: Account<FactorySource["Wallet"]>, newManager: Address, callbacks: CallbackType[]) {
    return initiator.runTarget(
      {
        contract: this.contract,
        value: locklift.utils.toNano(5),
        flags: 1,
      },
      nft =>
        nft.methods.changeManager({
          newManager,
          sendGasTo: initiator.address,
          callbacks,
        }),
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
