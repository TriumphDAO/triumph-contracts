// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IGovernanceAggregator {

    struct approvedAsset {
        address token; //Token contract address
        bool approved; //Token is approved (True) or removed (False)
    }

    struct cumulativeAssetCeiling {
        address token; //Token contract address
        uint96 index; //Location in index
        uint256 ceiling; //Maximum amount of tokens allowed to be purchased in bond markets
        string assetClass; //Category of asset; Public good, common good, positive externality
    }

    //EVENTS

    event newAssetApproved(address indexed token);
    event assetRemoved(address indexed token);
    event assetCeilingRaised(address token , uint256 amount , uint256 newTotal);

}
