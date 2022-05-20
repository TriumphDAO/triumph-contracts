import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const tocDeployment = await deployments.get(CONTRACTS.toc);
    const stakingDeployment = await deployments.get(CONTRACTS.staking);
    const authorityDeployment = await deployments.get(CONTRACTS.authority);

    // TODO: firstEpochBlock is passed in but contract constructor param is called _nextEpochBlock
    await deploy(CONTRACTS.distributor, {
        from: deployer,
        args: [
            treasuryDeployment.address,
            tocDeployment.address,
            stakingDeployment.address,
            authorityDeployment.address,
        ],
        log: true,
    });
};

func.tags = [CONTRACTS.distributor, "staking"];
func.dependencies = [
    CONTRACTS.treasury,
    CONTRACTS.toc,
    CONTRACTS.bondingCalculator,
    CONTRACTS.triumphAuthority,
];

export default func;
