import * as fs from "fs/promises";
import * as path from "path";

const writeAbi = async () => {
  const folders = [
    "CyberId.sol/CyberId.json",
    "RealmId.sol/RealmId.json",
    "PermissionMw.sol/PermissionMw.json",
    "StableFeeMiddleware.sol/StableFeeMiddleware.json",
    "TrustOnlyMiddleware.sol/TrustOnlyMiddleware.json",
    "PermissionMiddleware.sol/PermissionMiddleware.json",
    "PermissionedStableFeeMiddleware.sol/PermissionedStableFeeMiddleware.json",
  ];
  const ps = folders.map(async (file) => {
    const f = await fs.readFile(path.join("./out", file), "utf8");
    const json = JSON.parse(f);
    const fileName = path.parse(file).name;
    return fs.writeFile(
      path.join("docs/abi", `${fileName}.json`),
      JSON.stringify(json.abi)
    );
  });
  await Promise.all(ps);
};

const main = async () => {
  await writeAbi();
};

main()
  .then(() => {})
  .catch((err) => {
    console.error(err);
  });
