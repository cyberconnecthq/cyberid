const register = async () => {
  require("dotenv").config();
  const { ethers } = require("ethers");
  const { signTypedData_v4 } = require("eth-sig-util");
  const fs = require("fs");
  const MocaId = JSON.parse(fs.readFileSync("../../docs/abi/MocaId.json"));

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
    EIP712Domain: [
      { name: "name", type: "string" },
      { name: "version", type: "string" },
      { name: "chainId", type: "uint256" },
      { name: "verifyingContract", type: "address" },
    ],
  };

  const typedData = {
    data: {
      types: types,
      domain: domain,
      primaryType: "register",
      message: message,
    },
  };

  const Web3 = require("web3");
  let web3 = new Web3(provider);
  const signatureString = signTypedData_v4(
    Buffer.from(privateKey, "hex"),
    typedData
  );

  const signature = ethers.utils.splitSignature(signatureString);

  const r = signature.r;
  const s = signature.s;
  const v = signature.v;
  console.log(v, r, s);

  const data = web3.eth.abi.encodeParameters(
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
