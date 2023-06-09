import * as fs from "fs";
import chalk from "chalk";
import ora from "ora";
import prompts from "prompts";
const isDev = locklift.context.network.name !== "mainnet";
const envStringPart = isDev ? "dev" : "main";
import { SimpleKeystore } from "everscale-standalone-client/nodejs";
import { add0x } from "@growth-driver/everscale-contracts-tip4/utils/utils";
import devKeys from "../keys/root.dev.keys.json";
import mainKeys from "../keys/root.main.keys.json";
import { zeroAddress } from "locklift";

async function main() {
  const spinner = ora();

  const keys = isDev ? devKeys : mainKeys;
  await locklift.keystore.addKeyPair("default", {
    publicKey: keys.public,
    secretKey: keys.secret,
  });
  const signer = (await locklift.keystore.getSigner("default"))!;
  let randKeypair = SimpleKeystore.generateKeyPair();
  await locklift.keystore.addKeyPair("random", randKeypair);

  const offerArtifact = await locklift.factory.getContractArtifacts("Auction");

  const defaultName = "AuctionRoot";
  const promptResponse = await prompts([
    {
      type: "text",
      name: "addressName",
      message: "AuctionRoot name",
      initial: defaultName,
    },
    {
      type: "text",
      name: "withdrawalAddress",
      message: "withdrawal address",
      initial: zeroAddress,
    },
  ]);
  const rootName = promptResponse.addressName ?? defaultName;

  spinner.start("Deploy AuctionRoot");

  try {
    const addressesFilePath = `addresses/addresses-${envStringPart}.json`;
    let addresses = fs.existsSync(addressesFilePath) ? JSON.parse(fs.readFileSync(addressesFilePath)) : {};

    const { contract: root, tx } = await locklift.factory.deployContract({
      contract: "AuctionRoot",
      publicKey: (await locklift.keystore.getSigner("random")).publicKey,
      initParams: {},
      constructorParams: {
        ownerPubkey: add0x(signer.publicKey),
        offerCode: offerArtifact.code,
        deploymentFee: locklift.utils.toNano(1.5),
        creationPrice: locklift.utils.toNano(0.3),
        minimalGasAmount: locklift.utils.toNano(0.2),
        nftGasAmount: locklift.utils.toNano(0.1),
        leftOnOfferAfterFinish: locklift.utils.toNano(0.01),
        nftTransferFee: locklift.utils.toNano(1.1),
        methodsCallsFee: locklift.utils.toNano(0.1),
        marketFee: 3,
        marketFeeDecimals: 0,
        withdrawalAddress: promptResponse.withdrawalAddress,
        auctionBidDelta: 10,
        extraSecondsAmount: 0,
      },
      value: locklift.utils.toNano(2),
    });

    addresses[rootName] = root.address.toString();
    fs.writeFileSync(addressesFilePath, JSON.stringify(addresses, null, 2));

    const rootBalance = await locklift.provider.getBalance(root.address);
    spinner.succeed(
      chalk.green(
        `${chalk.bold.yellow(rootName)} deployed at: ${root.address.toString()} (Balance: ${locklift.utils.fromNano(
          rootBalance,
        )})`,
      ),
    );
  } catch (e) {
    spinner.fail(chalk.red("Failed deploy"));
    console.log(e);
  }
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
