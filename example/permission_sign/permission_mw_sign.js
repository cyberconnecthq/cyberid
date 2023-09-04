require("dotenv").config();
const { ethers } = require("ethers");
const RealmIdAbi = require("../../docs/abi/RealmId.json");
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
const RealmIdAddress = "0x1ef669e1a6d2aeef4741761488d473ece9810b05";
const PermissionMwAddress = "0x31f627dc0030334e62f8ca53c3cf730bb8417081";

// ------------- register params -------------
// 2033-05-18T11:33:20, can be updated to a value that wish the signature to be expired
const deadline = 2000000000;
// the name to register
const nameToRegister = "jack";
// the address to register to
const to = "0x2E0446079705B6Bacc4730fB3EDA5DA68aE5Fe4D";
const realmNode =
  "0xbfa0715290784075e564f966fffd9898ace1d7814f833780f62e59b079135746";
// *** IMPORTANT ***

const register = async () => {
  const privateKey = process.env.PRIVATE_KEY;
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);

  // in the demo, we use the signer EOA to sign and broadcast the transaction
  // in production, we can use the signer EOA to sign and use different EOA to broadcast the transaction
  const wallet = new ethers.Wallet(privateKey, provider);

  // the contract address may change if the RealmId contract set new middlewares
  const domain = {
    name: "PermissionMw",
    version: "1",
    chainId: 80001,
    verifyingContract: PermissionMwAddress,
  };

  const permissionMwContract = new ethers.Contract(
    // RealmId contract address
    PermissionMwAddress,
    PermissionMwAbi,
    wallet
  );

  // gets the nonce of the to address on chain
  const nonce = await permissionMwContract.nonces(to);

  const message = {
    name: nameToRegister,
    to: to,
    parentNode: realmNode,
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
  const realmIdContract = new ethers.Contract(
    // RealmId contract address
    RealmIdAddress,
    RealmIdAbi,
    wallet
  );
  const tx = await realmIdContract.register(
    nameToRegister,
    realmNode,
    to,
    data
  );
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
