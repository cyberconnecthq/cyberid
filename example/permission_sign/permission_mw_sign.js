require("dotenv").config();
const { ethers } = require("ethers");
const MocaId = require("../../docs/abi/MocaId.json");
const register = async () => {
  const privateKey = process.env.PRIVATE_KEY;
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);
  const domain = {
    name: "PermissionMw",
    version: "1",
    chainId: 80001,
    verifyingContract: "0x78a4c35cccc4eca7d987fdc38811c73ed36c2321",
  };

  // 2033-05-18T11:33:20
  const deadline = 2000000000;

  const message = {
    name: "alice",
    to: "0x2E0446079705B6Bacc4730fB3EDA5DA68aE5Fe4D",
    nonce: 0,
    deadline: deadline,
  };

  const types = {
    register: [
      { name: "name", type: "string" },
      { name: "to", type: "address" },
      { name: "nonce", type: "uint256" },
      { name: "deadline", type: "uint256" },
    ],
  };

  // const typedData = {
  //   types: types,
  //   domain: domain,
  //   primaryType: "register",
  //   message: message,
  // };

  const signatureString = await wallet._signTypedData(domain, types, message);

  const signature = ethers.utils.splitSignature(signatureString);

  const r = signature.r;
  const s = signature.s;
  const v = signature.v;

  const abiCoder = new ethers.utils.AbiCoder();
  const data = abiCoder.encode(
    ["uint8", "bytes32", "bytes32", "uint256"],
    [v, r, s, deadline]
  );

  console.log(data);

  const mocaIdContract = new ethers.Contract(
    "0x42fa95cdc898b40d8e9ddafb4db90df560a8d62e",
    MocaId,
    wallet
  );

  const tx = await mocaIdContract.register(
    "alice",
    "0x2E0446079705B6Bacc4730fB3EDA5DA68aE5Fe4D",
    data,
    "0x"
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
