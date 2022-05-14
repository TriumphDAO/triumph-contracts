// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.5;

import "./libraries/SafeMath.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/ITOC.sol";
import "./interfaces/IERC20Permit.sol";

import "./types/ERC20Permit.sol";
import "./types/TOCAccessControlled.sol";

contract BondholderERC20Token is ERC20Permit, ITOC, TOCAccessControlled {
    using SafeMath for uint256;

    constructor(address _authority) {
        ERC20("BondTOC***", "bTOC", 9); // Working name for token
        ERC20Permit("BondTOC***"); // Working name
        TOCAccessControlled(ITOCAuthority(_authority));
    }

    function mint(address account_, uint256 amount_) external override onlyVault {
        _mint(account_, amount_);
    }

    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account_, uint256 amount_) external override {
        _burnFrom(account_, amount_);
    }

    function _burnFrom(address account_, uint256 amount_) internal {
        uint256 decreasedAllowance_ = allowance(account_, msg.sender).sub(
            amount_,
            "ERC20: burn amount exceeds allowance"
        );

        _approve(account_, msg.sender, decreasedAllowance_);
        _burn(account_, amount_);
    }
}
