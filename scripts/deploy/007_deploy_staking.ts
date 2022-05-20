import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {
    CONTRACTS,
    EPOCH_LENGTH_IN_BLOCKS,
    FIRST_EPOCH_TIME,
    FIRST_EPOCH_NUMBER,
} from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const tocDeployment = await deployments.get(CONTRACTS.toc);
    const sTocDeployment = await deployments.get(CONTRACTS.sToc);

    await deploy(CONTRACTS.staking, {
        from: deployer,
        args: [
            tocDeployment.address,
            sTocDeployment.address,
            EPOCH_LENGTH_IN_BLOCKS,
            FIRST_EPOCH_NUMBER,
            FIRST_EPOCH_TIME,
            authorityDeployment.address,
        ],
        log: true,
    });
};

func.tags = [CONTRACTS.staking, "staking"];
func.dependencies = [CONTRACTS.toc, CONTRACTS.sToc];

export default func;
