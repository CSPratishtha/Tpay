import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const LockModule = buildModule("LockModule", (m) => {
  // Set parameters for TPAYToken constructor
  const owner = m.getParameter("owner", "0x7f5a36d85f4e2159b894815166dB830dD357BbCb");
  const treasury = m.getParameter("treasury", "0x7f5a36d85f4e2159b894815166dB830dD357BbCb");

  // Deploy TPAYToken with 2 constructor arguments
  const token = m.contract("TPAYToken", [owner, treasury]);

  // Deploy Lock with token + owner
  const lock = m.contract("Lock", [token, owner]);

  return { token, lock };
});

export default LockModule;
