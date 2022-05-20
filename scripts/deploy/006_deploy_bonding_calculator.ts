import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { OlympusERC20Token__factory } from "../../types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    const tocDeployment = await deployments.get(CONTRACTS.toc);
    const toc = await OlympusERC20Token__factory.connect(tocDeployment.address, signer);

    await deploy(CONTRACTS.bondingCalculator, {
        from: deployer,
        args: [toc.address],
        log: true,
        skipIfAlreadyDeployed: true,
    });
};

func.tags = [CONTRACTS.bondingCalculator, "staking", "bonding"];
func.dependencies = [CONTRACTS.toc];

export default func;
