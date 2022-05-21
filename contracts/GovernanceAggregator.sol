// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./interfaces/ITreasury.sol";
import "usingtellor/contracts/UsingTellor.sol";

import "./interfaces/IGovernanceAggregator.sol";
import "./types/TriumphAccessControlled.sol";
import "./interfaces/IERC20.sol";

abstract contract GovernanceAggregator is ITreasury, IGovernanceAggregator, TriumphAccessControlled, IERC20, UsingTellor {
    constructor() {

    }

// STORAGE // 
mapping(address => approvedAsset[]) public approvedAssets;
mapping(address => cumulativeAssetCeiling[]) public cumulativeAssetCeilings;

// MODIFIERS //

    modifier isApprovedAsset(address token) {
        require(approvedAsset.approved == true, "Asset is not approved");
        _;
    } 

    modifier assetCeiling(IERC20 _quoteToken, bool[2] storage _booleans) {
        require(cumulativeAssetCeilings[_quoteToken].ceiling + ITreasury.IERC20.balanceOf(_quoteToken) >= _booleans[0], 
        "Bond market capacity exceeds the asset ceiling for this token.");
        _;
    }

// FUNCTIONS //

//Add approved asset to list
function approveByVote(address _token, string calldata _assetClass) public approvedAsset onlyPolicy {
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
    uint[] memory assetInfo = cumulativeAssetCeiling[_token];
    uint256 currentCeiling = assetInfo.ceiling;

    assetInfo.ceiling = currentCeiling + _ceiling;
        emit assetCeilingRaised(_token, _ceiling, assetInfo.ceiling);
}

}

