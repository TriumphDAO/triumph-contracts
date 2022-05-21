// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "usingtellor/contracts/UsingTellor.sol";

import "./interfaces/IGovernanceAggregator.sol";
import "./interfaces/ITriumphAccessControlled.sol";

contract GovernanceAggregator is Treasury, IGovernanceAggregator, ITriumphAccessControlled, IERC20, UsingTellor {
    constructor() {

    }

// VARIABLES //
mapping(address => approvedAsset[]) public approvedAssets;
mapping(address => cumulativeAssetCeiling[]) public cumulativeAssetCeilings;

// STORAGE // 
cumulativeAssetCeiling[] public cumulativeAssetCeilings;
approvedAsset[] public approvedAssets;

// MODIFIERS //

    modifier approvedAsset(address token) {
        require(approvedAsset.approved == true, "Asset is not approved");
        _;
    } 

    modifier assetCeiling(IERC20 _quoteToken, bool[2] _booleans) {
        require(cumulativeAssetCeilings[_quoteToken].ceiling + treasury.IERC20.balanceOf(_quoteToken) >= _booleans[0], 
        "Bond market capacity exceeds the asset ceiling for this token.");
        _;
    }

// FUNCTIONS //

//Add approved asset to list
function approveByVote(address _token, string _assetClass) public approvedAsset onlyPolicy {
    //TODO Can Tally execute automatically?
    approvedAssets.push(
        approvedAsset({
            token: _token,
            approved: true
        })
    );

    cumulativeAssetCeilings.push(
        cumulativeAssetCeiling({
            token: _token,
            index: cumulativeAssetCeilings.length + 1,
            ceiling: 0,
            assetClass: _assetClass 
        })
    );
}

//Increment the cumulative asset ceiling for a token, increasing the capacity that bond markets can use to purchase them
function incrementAssetCeiling(address _token, uint256 _ceiling) public approvedAsset onlyPolicy {
    //TODO What does the data from Tellor look like?
    assetInfo = cumulativeAssetCeiling[_token];
    currentCeiling = assetInfo.ceiling;

    assetInfo.ceiling = currentCeiling + _ceiling;
        emit assetCeilingRaised(_token, _ceiling, assetInfo.ceiling);
}

}

