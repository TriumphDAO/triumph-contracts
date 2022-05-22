// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./Treasury.sol";
import "usingtellor/contracts/UsingTellor.sol";

import "./interfaces/IGovernanceAggregator.sol";
import "./types/TriumphAccessControlled.sol";
import "./interfaces/IERC20.sol";

abstract contract GovernanceAggregator is IGovernanceAggregator, TriumphAccessControlled, IERC20, TriumphTreasury, UsingTellor {
    
    address private immutable treasury;

    constructor(
        address _treasury
    ) {
        treasury = _treasury;
    }

// STORAGE // 

    ApprovedAsset[] public approvedAssets;
    CumulativeAssetCeiling[] public cumulativeAssetCeilings;

// MODIFIERS //

    modifier isApprovedAsset(uint256 _quoteToken) {
        ApprovedAsset storage approvedAsset = approvedAssets[_quoteToken];
        require(approvedAsset.approved = true, "Asset is not approved");
        _;
    } 

    modifier assetCeiling(uint256 _quoteToken, bool[2] storage _booleans) {
        CumulativeAssetCeiling storage cumulativeAssetCeiling = cumulativeAssetCeilings[_quoteToken];

        require(cumulativeAssetCeiling.ceiling + IERC20(_quoteToken).balanceOf(treasury) >= _booleans[0], 
        "Bond market capacity exceeds the asset ceiling for this token.");
        _;
    }

// FUNCTIONS //

//Add approved asset to list
function approveByVote(address _token, string calldata _assetClass) public isApprovedAsset onlyPolicy {
    //TODO Can Tally execute automatically?
    approvedAssets.push(
        ApprovedAsset({
            token: _token,
            approved: true
        })
    );

    cumulativeAssetCeilings.push(
        CumulativeAssetCeiling({
            token: _token,
            index: cumulativeAssetCeilings.length + 1,
            ceiling: 0,
            assetClass: _assetClass 
        })
    );
}

//Increment the cumulative asset ceiling for a token, increasing the capacity that bond markets can use to purchase them
function incrementAssetCeiling(address _token, uint256 _ceiling) public isApprovedAsset onlyPolicy returns(uint256 cumulativeAssetCeiling) {
    //TODO What does the data from Tellor look like?
    CumulativeAssetCeiling storage cumulativeAssetCeiling = cumulativeAssetCeilings[_token];
    uint256 currentCeiling = cumulativeAssetCeiling.ceiling;

    cumulativeAssetCeiling.ceiling = currentCeiling + _ceiling;
        emit assetCeilingRaised(_token, _ceiling, currentCeiling);
}

}
