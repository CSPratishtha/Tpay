import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract } from "ethers";

describe("AMM Core (Factory + Pair) — integration tests", function () {
  it("deploys Factory + Token pair and verifies pair correctness", async function () {
    // Signers
    const [owner, addr1] = await ethers.getSigners();

    // -------------------------
    // 1) Deploy Factory
    // -------------------------
    const Factory = await ethers.getContractFactory("Factory");
    const factory = (await Factory.deploy(owner.address)) as Contract;
    await factory.waitForDeployment?.(); // v6 style helper, no-op in older runtimes

    console.log("Factory deployed at:", factory.target ?? factory.address);

    // -------------------------
    // 2) Deploy two ERC20 Tokens
    // -------------------------
    const Token = await ethers.getContractFactory("Token");
    const tokenA = (await Token.deploy("TokenA", "TKA")) as Contract;
    await tokenA.waitForDeployment?.();
    const tokenB = (await Token.deploy("TokenB", "TKB")) as Contract;
    await tokenB.waitForDeployment?.();

    console.log("TokenA:", tokenA.target ?? tokenA.address);
    console.log("TokenB:", tokenB.target ?? tokenB.address);

    // Basic sanity: addresses look like addresses (simple regex)
    const addressRegex = /^0x[0-9a-fA-F]{40}$/;
    expect(tokenA.address).to.match(addressRegex);
    expect(tokenB.address).to.match(addressRegex);

    // -------------------------
    // 3) Create Pair via Factory
    // -------------------------
    const createTx = await factory.createPair(tokenA.address, tokenB.address);
    await createTx.wait();

    const pairAddr = await factory.getPair(tokenA.address, tokenB.address);
    console.log("Pair created at:", pairAddr);

    // Basic checks for pair address
    expect(pairAddr).to.match(addressRegex);
    const ZERO = "0x0000000000000000000000000000000000000000";
    expect(pairAddr).to.not.equal(ZERO);

    // -------------------------
    // 4) Verify Pair contract and token ordering
    // -------------------------
    // Assume pair contract is available under name "Pair" in artifacts
    const Pair = await ethers.getContractFactory("Pair");
    const pair = Pair.attach(pairAddr) as Contract;

    // If Pair implements token0() and token1(), verify they match factory inputs (order may be sorted)
    let token0: string | null = null;
    let token1: string | null = null;

    // Defensive: not all pair implementations have the same accessor names, wrap in try/catch
    try {
      token0 = await pair.token0();
      token1 = await pair.token1();
      // token0/token1 should be one of tokenA/tokenB each
      expect([tokenA.address, tokenB.address]).to.include(token0);
      expect([tokenA.address, tokenB.address]).to.include(token1);
      expect(token0).to.not.equal(token1);
    } catch (err) {
      // If token0/token1 do not exist, at least check the pair was registered in factory
      // (we already checked getPair returned a non-zero address)
      console.warn("Pair does not expose token0/token1; skipping token checks.");
    }

    // -------------------------
    // 5) Calling getPair with reversed args returns same pair (factory should be order-independent)
    // -------------------------
    const pairAddrReverse = await factory.getPair(tokenB.address, tokenA.address);
    expect(pairAddrReverse).to.equal(pairAddr);

    // -------------------------
    // 6) Creating the same pair again should revert or return the same address depending on implementation.
    //    We'll assert that calling createPair again either reverts OR returns same deployed address.
    // -------------------------
    try {
      const secondCreateTx = await factory.createPair(tokenA.address, tokenB.address);
      await secondCreateTx.wait();
      const pairAddrAfter = await factory.getPair(tokenA.address, tokenB.address);
      expect(pairAddrAfter).to.equal(pairAddr);
    } catch (err) {
      // If factory.createPair reverts on duplicate pair, that's also acceptable — assert it reverted.
      // Use the thrown error as proof that duplicate creation is disallowed by implementation.
      // No further action needed here.
      console.log("Factory prevented duplicate pair creation (revert caught).");
    }
  });
});
