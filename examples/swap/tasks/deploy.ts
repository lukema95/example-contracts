import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const network = hre.network.name as any;

  const [signer] = await hre.ethers.getSigners();
  if (signer === undefined) {
    throw new Error(
      `Wallet not found. Please, run "npx hardhat account --save" or set PRIVATE_KEY env variable (for example, in a .env file)`
    );
  }

  const factory = await hre.ethers.getContractFactory(args.name);
  const contract = await (factory as any).deploy(
    args.systemContract,
    args.gateway
  );
  await contract.deployed();

  if (args.json) {
    console.log(JSON.stringify(contract));
  } else {
    console.log(`🔑 Using account: ${signer.address}

🚀 Successfully deployed contract on ${network}.
📜 Contract address: ${contract.address}
`);
  }
};

task("deploy", "Deploy the contract", main)
  .addFlag("json", "Output in JSON")
  .addOptionalParam("name", "Contract to deploy", "Swap")
  .addOptionalParam(
    "systemContract",
    "System contract",
    "0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0"
  )
  .addOptionalParam(
    "gateway",
    "Gateway address (default: ZetaChain Gateway)",
    "0x9A676e781A523b5d0C0e43731313A708CB607508"
  );
