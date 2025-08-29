import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("FactoryModule", (m) => {
  // Replace with the deployer or the address you want as feeToSetter (e.g., deployer or timelock later)
  const factory = m.contract("TPayFactory", [
    // put your deployer or timelock address here
    "0x7f5a36d85f4e2159b894815166dB830dD357BbCb"
  ]);

  return { factory };
});
