import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const bTOCDeployment = await deployments.get(CONTRACTS.bTOC);

    await deploy(CONTRACTS.governor, {
        from: deployer,
        args: [bTOCDeployment.address, deployer],
        log: true,
        skipIfAlreadyDeployed: true,
    });
};

func.tags = [CONTRACTS.governor, "governance"];
func.dependencies = [CONTRACTS.bTOC];

export default func;
