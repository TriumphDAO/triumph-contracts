// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IGovernanceAggregator {

    struct ApprovedAsset {
        uint256 token; //Token contract address
        bool approved; //Token is approved (True) or removed (False)
    }

    struct CumulativeAssetCeiling {
        uint256 token; //Token contract address
        uint256 index; //Location in index
        uint256 ceiling; //Maximum amount of tokens allowed to be purchased in bond markets
        string assetClass; //Category of asset; Public good, common good, positive externality
    }

    //EVENTS

    event newAssetApproved(uint256 token);
    event assetRemoved(uint256 token);
    event assetCeilingRaised(uint256 token , uint256 amount , uint256 newTotal);

}
