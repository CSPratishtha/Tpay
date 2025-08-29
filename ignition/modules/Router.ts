import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Router", (m) => {
  // Factory address required for Router constructor
  const factoryAddress = "0xYourFactoryAddressHere"; 

  const router = m.contract("Router", [factoryAddress]);

  return { router };
});
