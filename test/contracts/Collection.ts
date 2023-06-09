import { Address, Contract, ContractMethods } from "locklift";
import { FactorySource, CollectionSampleAbi } from "../../build/factorySource";

export class Collection {
    public contract: Contract<FactorySource["CollectionSample"]>;
    public address: Address;
    public methods: ContractMethods<CollectionSampleAbi>;

    constructor(contract: Contract<FactorySource["CollectionSample"]>) {
        this.contract = contract;
        this.address = this.contract.address;
        this.methods = contract.methods;
    }

    async getEvents(eventName: string) {
        return (await this.contract.getPastEvents({filter: (event) => event.event === eventName})).events;
    }
    
    async getLastEvent(eventName: string) {
        const lastEvent = (await this.getEvents(eventName)).shift();

        return lastEvent?.data;
    }
}