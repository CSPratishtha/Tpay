import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("TokenModule", (m) => {
  const counter = m.contract("TpayToken");
  return { counter };
});
