import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();
  if (signer === undefined) {
    throw new Error(
      `Wallet not found. Please, run "npx hardhat account --save" or set PRIVATE_KEY env variable (for example, in a .env file)`
    );
  }

  const contract: any = await hre.ethers.getContractAt(
    args.name,
    args.contract
  );

  const recipient = args.to || signer.address;

  const tx = await contract.mint(recipient, args.amount);
  const receipt = await tx.wait();

  const transferEvent = receipt.events?.find(
    (event: any) => event.event === "Transfer"
  );
  const tokenId = transferEvent?.args?.tokenId;

  if (args.json) {
    console.log(
      JSON.stringify({
        contractAddress: args.contract,
        mintTransactionHash: tx.hash,
        recipient: recipient,
        tokenURI: args.tokenUri,
        tokenId: tokenId?.toString(),
      })
    );
  } else {
    console.log(`🚀 Successfully minted NFT.
📜 Contract address: ${args.contract}
👤 Recipient: ${recipient}
🆔 Token ID: ${tokenId?.toString()}
🔗 Transaction hash: ${tx.hash}`);
  }
};

task("mint", "Mint an NFT", main)
  .addParam("contract", "The address of the deployed NFT contract")
  .addOptionalParam(
    "to",
    "The recipient address, defaults to the signer address"
  )
  .addParam("amount", "The amount of tokens to mint")
  .addOptionalParam("name", "The contract name to interact with", "Universal")
  .addFlag("json", "Output the result in JSON format");