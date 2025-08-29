import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Pair", (m) => {
  // deploy Pair contract
  const pair = m.contract("Pair");

  return { pair };
});
