import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { waitFor } from "../txHelper";
import { CONTRACTS, INITIAL_REWARD_RATE, INITIAL_INDEX, BOUNTY_AMOUNT } from "../constants";
import {
    OlympusAuthority__factory,
    Distributor__factory,
    OlympusERC20Token__factory,
    OlympusStaking__factory,
    SOlympus__factory,
    Gtoc__factory,
    OlympusTreasury__factory,
    LUSDAllocator__factory,
} from "../../types";

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const tocDeployment = await deployments.get(CONTRACTS.toc);
    const sTocDeployment = await deployments.get(CONTRACTS.sToc);
    const distributorDeployment = await deployments.get(CONTRACTS.distributor);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const stakingDeployment = await deployments.get(CONTRACTS.staking);

    const authorityContract = await OlympusAuthority__factory.connect(
        authorityDeployment.address,
        signer
    );
    const toc = OlympusERC20Token__factory.connect(tocDeployment.address, signer);
    const sToc = SOlympus__factory.connect(sTocDeployment.address, signer);
    const distributor = Distributor__factory.connect(distributorDeployment.address, signer);
    const staking = OlympusStaking__factory.connect(stakingDeployment.address, signer);
    const treasury = OlympusTreasury__factory.connect(treasuryDeployment.address, signer);

    // Step 1: Set treasury as vault on authority
    await waitFor(authorityContract.pushVault(treasury.address, true));
    console.log("Setup -- authorityContract.pushVault: set vault on authority");

    // Step 2: Set distributor as minter on treasury
    await waitFor(treasury.enable(8, distributor.address, ethers.constants.AddressZero)); // Allows distributor to mint toc.
    console.log("Setup -- treasury.enable(8):  distributor enabled to mint toc on treasury");

    // Step 3: Set distributor on staking
    await waitFor(staking.setDistributor(distributor.address));
    console.log("Setup -- staking.setDistributor:  distributor set on staking");

    // Step 4: Initialize sToc and set the index
    if ((await sToc.gtoc()) == ethers.constants.AddressZero) {
        await waitFor(sToc.setIndex(INITIAL_INDEX)); // TODO
        await waitFor(sToc.setgtoc(gtoc.address));
        await waitFor(sToc.initialize(staking.address, treasuryDeployment.address));
    }
    console.log("Setup -- sToc initialized (index, gtoc)");

    // Step 5: Set up distributor with bounty and recipient
    await waitFor(distributor.setBounty(BOUNTY_AMOUNT));
    await waitFor(distributor.addRecipient(staking.address, INITIAL_REWARD_RATE));
    console.log("Setup -- distributor.setBounty && distributor.addRecipient");

    // Approve staking contact to spend deployer's toc
    // TODO: Is this needed?
    // await toc.approve(staking.address, LARGE_APPROVAL);
};

func.tags = ["setup"];
func.dependencies = [CONTRACTS.toc, CONTRACTS.sToc];

export default func;
