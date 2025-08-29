import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("TokenModule", (m) => {
  const counter = m.contract("Treasury" , [ "0x7f5a36d85f4e2159b894815166dB830dD357BbCb"]);
  return { counter };
});
