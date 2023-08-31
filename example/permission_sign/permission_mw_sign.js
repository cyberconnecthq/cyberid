require("dotenv").config();
const { ethers } = require("ethers");
const MocaIdAbi = require("../../docs/abi/MocaId.json");
const PermissionMwAbi = require("../../docs/abi/PermissionMw.json");

// EIP712 types
// register(string name,bytes32 parentNode,address to,uint256 nonce,uint256 deadline)
const types = {
  register: [
    { name: "name", type: "string" },
    { name: "parentNode", type: "bytes32" },
    { name: "to", type: "address" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

// *** IMPORTANT ***
// update below values to correct values
// ------------- contract addresses -------------
const MocaIdAddress = "0x5904e2d41a677e6906243d2b0555c1dc73e7998c";
const PermissionMwAddress = "0xa2668a6b7670e45944331b276626db873cabd24d";

// ------------- register params -------------
// 2033-05-18T11:33:20, can be updated to a value that wish the signature to be expired
const deadline = 2000000000;
// the name to register
const nameToRegister = "jack";
// the address to register to
const to = "0x2E0446079705B6Bacc4730fB3EDA5DA68aE5Fe4D";
const mocaNode =
  "0xbfa0715290784075e564f966fffd9898ace1d7814f833780f62e59b079135746";
// *** IMPORTANT ***

const register = async () => {
  const privateKey = process.env.PRIVATE_KEY;
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);

  // in the demo, we use the signer EOA to sign and broadcast the transaction
  // in production, we can use the signer EOA to sign and use different EOA to broadcast the transaction
  const wallet = new ethers.Wallet(privateKey, provider);

  // the contract address may change if the MocaId contract set new middlewares
  const domain = {
    name: "PermissionMw",
    version: "1",
    chainId: 80001,
    verifyingContract: PermissionMwAddress,
  };

  const permissionMwContract = new ethers.Contract(
    // MocaId contract address
    PermissionMwAddress,
    PermissionMwAbi,
    wallet
  );

  // gets the nonce of the to address on chain
  const nonce = await permissionMwContract.nonces(to);

  const message = {
    name: nameToRegister,
    to: to,
    parentNode: mocaNode,
    nonce: nonce.toNumber(),
    deadline: deadline,
  };

  // sign the data using signer EOA
  const signatureString = await wallet._signTypedData(domain, types, message);
  const signature = ethers.utils.splitSignature(signatureString);

  // encode the signature data and deadline
  const abiCoder = new ethers.utils.AbiCoder();
  const data = abiCoder.encode(
    ["uint8", "bytes32", "bytes32", "uint256"],
    [signature.v, signature.r, signature.s, deadline]
  );

  // register the name using the signature data
  const mocaIdContract = new ethers.Contract(
    // MocaId contract address
    MocaIdAddress,
    MocaIdAbi,
    wallet
  );
  const tx = await mocaIdContract.register(nameToRegister, mocaNode, to, data);
  await tx.wait();
  console.log("Transaction hash:", tx.hash);
};

const main = async () => {
  await register();
};

main()
  .then(() => {})
  .catch((err) => {
    console.error(err);
  });
