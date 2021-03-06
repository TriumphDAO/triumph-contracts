// // SPDX-License-Identifier: AGPL-3.0-or-later
// pragma solidity ^0.8.10;

// import {IERC20} from "../interfaces/IERC20.sol";
// import {IsTOC} from "../interfaces/IsTOC.sol";
// import {IStaking} from "../interfaces/IStaking.sol";
// import {IYieldDirector} from "../interfaces/IYieldDirector.sol";
// import {SafeERC20} from "../libraries/SafeERC20.sol";
// import {YieldSplitter} from "../types/YieldSplitter.sol";
// import {TriumphAccessControlled, ITriumphAuthority} from "../types/TriumphAccessControlled.sol";

// /**
//     @title  YieldDirector (codename Tyche) 
//     @notice This contract allows donors to deposit their bTOC and donate their rebases
//             to any address. Donors will be able to withdraw the sTOC equivalent of their principal
//             bTOC at any time. Donation recipients can also redeem accrued rebases at any time.
//     @dev    Any functions dealing with initial deposits will take an address (because no ID has been
//             assigned). After a user has deposited, all functions dealing with deposits (like
//             withdraw or redeem functions) will take the ID of the deposit. All functions that return
//             aggregated data grouped by user will take an address (iterates across all relevant IDs).
//  */
// abstract contract YieldDirector is IYieldDirector, YieldSplitter, TriumphAccessControlled {
//     using SafeERC20 for IERC20;

//     error YieldDirector_InvalidAddress();
//     error YieldDirector_InvalidDeposit();
//     error YieldDirector_InvalidUpdate();
//     error YieldDirector_InvalidWithdrawal();
//     error YieldDirector_NotYourYield();
//     error YieldDirector_NoDeposits();
//     error YieldDirector_WithdrawalsDisabled();
//     error YieldDirector_RedeemsDisabled();

//     address public immutable sTOC;
//     address public immutable bTOC;
//     IStaking public immutable staking;

//     mapping(address => uint256[]) public recipientIds; // address -> array of deposit id's donating yield to the user
//     mapping(uint256 => address) public recipientLookup; // depositId -> recipient

//     bool public depositDisabled;
//     bool public withdrawDisabled;
//     bool public redeemDisabled;

//     event Deposited(address indexed donor_, address indexed recipient_, uint256 amount_);
//     event Withdrawn(address indexed donor_, address indexed recipient_, uint256 amount_);
//     event AllWithdrawn(address indexed donor_, uint256 indexed amount_);
//     event Donated(address indexed donor_, address indexed recipient_, uint256 amount_);
//     event Redeemed(address indexed recipient_, uint256 amount_);
//     event EmergencyShutdown(bool active_);

//     constructor(
//         address sOhm_,
//         address gOhm_,
//         address staking_,
//         address authority_
//     ) TriumphAccessControlled(ITriumphAuthority(authority_)) YieldSplitter(sOhm_) {
//         if (sOhm_ == address(0) || gOhm_ == address(0) || staking_ == address(0) || authority_ == address(0))
//             revert YieldDirector_InvalidAddress();

//         sTOC = sOhm_;
//         bTOC = gOhm_;
//         staking = IStaking(staking_);

//         IERC20(sTOC).safeApprove(address(staking), type(uint256).max);
//     }

//     /************************
//      * Modifiers
//      ************************/
//     function isInvalidDeposit(uint256 amount_, address recipient_) internal view returns (bool) {
//         return depositDisabled || amount_ <= 0 || recipient_ == address(0);
//     }

//     function isInvalidUpdate(uint256 depositId_, uint256 amount_) internal view returns (bool) {
//         return depositDisabled || amount_ <= 0 || depositInfo[depositId_].depositor == address(0);
//     }

//     function isInvalidWithdrawal(uint256 amount_) internal view returns (bool) {
//         return withdrawDisabled || amount_ <= 0;
//     }

//     /************************
//      * Donor Functions
//      ************************/

//     /**
//         @notice Deposit bTOC, records sender address and assign rebases to recipient
//         @param amount_ Amount of bTOC debt issued from donor to recipient
//         @param recipient_ Address to direct staking yield and vault shares to
//     */
//     function deposit(uint256 amount_, address recipient_) external override returns (uint256 depositId) {
//         depositId = _createDeposit(amount_, recipient_);

//         IERC20(bTOC).safeTransferFrom(msg.sender, address(this), amount_);
//     }

//     /**
//         @notice Deposit sTOC, wrap to bTOC, and records sender address and assign rebases to recipeint
//         @param amount_ Amount of sTOC debt issued from donor to recipient
//         @param recipient_ Address to direct staking yield and vault shares to
//     */
//     function depositStoc(uint256 amount_, address recipient_) external override returns (uint256 depositId) {
//         uint256 gtocAmount = _toAgnostic(amount_);
//         depositId = _createDeposit(gtocAmount, recipient_);

//         IERC20(sTOC).safeTransferFrom(msg.sender, address(this), amount_);
//         staking.wrap(address(this), amount_);
//     }

//     /**
//         @notice Deposit additional bTOC, and update deposit record
//         @param depositId_ Deposit ID to direct additional bTOC to
//         @param amount_ Amount of new bTOC debt issued from donor to recipient
//     */
//     function addToDeposit(uint256 depositId_, uint256 amount_) external override {
//         _increaseDeposit(depositId_, amount_);

//         IERC20(bTOC).safeTransferFrom(msg.sender, address(this), amount_);
//     }

//     /**
//         @notice Deposit additional sTOC, wrap to bTOC, and update deposit record
//         @param depositId_ Deposit ID to direct additional bTOC to
//         @param amount_ Amount of new sTOC debt issued from donor to recipient
//     */
//     function addToStocDeposit(uint256 depositId_, uint256 amount_) external override {
//         uint256 gtocAmount = _toAgnostic(amount_);
//         _increaseDeposit(depositId_, gtocAmount);

//         IERC20(sTOC).safeTransferFrom(msg.sender, address(this), amount_);
//         staking.wrap(address(this), amount_);
//     }

//     /**
//         @notice Withdraw donor's bTOC from vault
//         @param depositId_ Deposit ID to remove bTOC deposit from
//         @param amount_ Amount of bTOC deposit to remove and return to donor
//     */
//     function withdrawPrincipal(uint256 depositId_, uint256 amount_) external override {
//         uint256 amountWithdrawn = _withdraw(depositId_, amount_);

//         IERC20(bTOC).safeTransfer(msg.sender, amountWithdrawn);
//     }

//     /**
//         @notice Withdraw donor's bTOC from vault, and return it as sTOC
//         @param depositId_ Deposit ID to remove bTOC debt from
//         @param amount_ Amount of bTOC debt to remove and return to donor as sTOC
//     */
//     function withdrawPrincipalAsStoc(uint256 depositId_, uint256 amount_) external override {
//         uint256 amountWithdrawn = _withdraw(depositId_, amount_);

//         staking.unwrap(msg.sender, amountWithdrawn);
//     }

//     /**
//         @notice Withdraw all bTOC from all donor positions
//     */
//     function withdrawAll() external override {
//         if (withdrawDisabled) revert YieldDirector_WithdrawalsDisabled();

//         uint256[] memory depositIds = depositorIds[msg.sender];

//         uint256 depositsLength = depositIds.length;
//         if (depositsLength == 0) revert YieldDirector_NoDeposits();

//         uint256 principalTotal = 0;

//         for (uint256 index = 0; index < depositsLength; ++index) {
//             DepositInfo storage currDeposit = depositInfo[depositIds[index]];

//             principalTotal += currDeposit.principalAmount;

//             _withdrawAllPrincipal(depositIds[index], msg.sender);
//         }

//         uint256 agnosticAmount = _toAgnostic(principalTotal);

//         emit AllWithdrawn(msg.sender, agnosticAmount);

//         IERC20(bTOC).safeTransfer(msg.sender, agnosticAmount);
//     }

//     /************************
//      * View Functions
//      ************************/

//     /**
//         @notice Get deposited bTOC amounts for specific recipient (updated to current index
//                 based on sTOC equivalent amount deposit)
//         @param donor_ Address of user donating yield
//         @param recipient_ Address of user receiving donated yield
//     */
//     function depositsTo(address donor_, address recipient_) external view override returns (uint256) {
//         uint256[] memory depositIds = depositorIds[donor_];

//         for (uint256 index = 0; index < depositIds.length; ++index) {
//             uint256 id = depositIds[index];

//             if (recipientLookup[id] == recipient_) {
//                 return _toAgnostic(depositInfo[id].principalAmount);
//             }
//         }

//         return 0;
//     }

//     /**
//         @notice Return total amount of donor's bTOC deposited (updated to current index based
//                 on sTOC equivalent amount deposited)
//         @param donor_ Address of user donating yield
//     */
//     function totalDeposits(address donor_) external view override returns (uint256) {
//         uint256[] memory depositIds = depositorIds[donor_];
//         uint256 principalTotal = 0;

//         for (uint256 index = 0; index < depositIds.length; ++index) {
//             principalTotal += depositInfo[depositIds[index]].principalAmount;
//         }

//         return _toAgnostic(principalTotal);
//     }

//     /**
//         @notice Return arrays of donor's recipients and deposit amounts (bTOC value based on
//                 sTOC equivalent deposit), matched by index
//         @param donor_ Address of user donating yield
//     */
//     function getAllDeposits(address donor_) external view override returns (address[] memory, uint256[] memory) {
//         uint256[] memory depositIds = depositorIds[donor_];

//         uint256 len = depositIds.length == 0 ? 1 : depositIds.length;

//         address[] memory addresses = new address[](len);
//         uint256[] memory agnosticDeposits = new uint256[](len);

//         if (depositIds.length == 0) {
//             addresses[0] = address(0);
//             agnosticDeposits[0] = 0;
//         } else {
//             for (uint256 index = 0; index < len; ++index) {
//                 addresses[index] = recipientLookup[depositIds[index]];
//                 agnosticDeposits[index] = _toAgnostic(depositInfo[depositIds[index]].principalAmount);
//             }
//         }

//         return (addresses, agnosticDeposits);
//     }

//     /**
//         @notice Return total amount of bTOC donated to recipient since last full redemption
//         @param donor_ Address of user donating yield
//         @param recipient_ Address of user recieiving donated yield
//     */
//     function donatedTo(address donor_, address recipient_) external view override returns (uint256) {
//         uint256[] memory depositIds = depositorIds[donor_];

//         for (uint256 index = 0; index < depositIds.length; ++index) {
//             if (recipientLookup[depositIds[index]] == recipient_) {
//                 return redeemableBalance(depositIds[index]);
//             }
//         }

//         return 0;
//     }

//     /**
//         @notice Return total amount of bTOC donated from donor since last full redemption
//         @param donor_ Address of user donating yield
//     */
//     function totalDonated(address donor_) external view override returns (uint256) {
//         uint256[] memory depositIds = depositorIds[donor_];

//         uint256 principalTotal = 0;
//         uint256 agnosticTotal = 0;

//         for (uint256 index = 0; index < depositIds.length; ++index) {
//             DepositInfo storage currDeposit = depositInfo[depositIds[index]];

//             principalTotal += currDeposit.principalAmount;
//             agnosticTotal += currDeposit.agnosticAmount;
//         }

//         return _getOutstandingYield(principalTotal, agnosticTotal);
//     }

//     /**
//         @notice Getter function for a depositor's list of IDs. This is needed for the frontend
//                 as public state variables that map to arrays only return one element at a time
//                 rather than the full array
//     */
//     function getDepositorIds(address donor_) external view override returns (uint256[] memory) {
//         return depositorIds[donor_];
//     }

//     /************************
//      * Recipient Functions
//      ************************/

//     /**
//         @notice Get redeemable bTOC balance of a specific deposit
//         @param depositId_ Deposit ID for this donation
//     */
//     function redeemableBalance(uint256 depositId_) public view override returns (uint256) {
//         DepositInfo storage currDeposit = depositInfo[depositId_];

//         return _getOutstandingYield(currDeposit.principalAmount, currDeposit.agnosticAmount);
//     }

//     /**
//         @notice Get redeemable bTOC balance of a recipient address
//         @param recipient_ Address of user receiving donated yield
//      */
//     function totalRedeemableBalance(address recipient_) public view override returns (uint256) {
//         uint256[] memory receiptIds = recipientIds[recipient_];

//         uint256 agnosticRedeemable = 0;

//         for (uint256 index = 0; index < receiptIds.length; ++index) {
//             agnosticRedeemable += redeemableBalance(receiptIds[index]);
//         }

//         return agnosticRedeemable;
//     }

//     /**
//         @notice Getter function for a recipient's list of IDs. This is needed for the frontend
//                 as public state variables that map to arrays only return one element at a time
//                 rather than the full array
//     */
//     function getRecipientIds(address recipient_) external view override returns (uint256[] memory) {
//         return recipientIds[recipient_];
//     }

//     /**
//         @notice Redeem recipient's donated amount of sTOC at current index from one donor as bTOC
//         @param depositId_ Deposit ID for this donation
//     */
//     function redeemYield(uint256 depositId_) external override {
//         uint256 amountRedeemed = _redeem(depositId_);

//         IERC20(bTOC).safeTransfer(msg.sender, amountRedeemed);
//     }

//     /**
//         @notice Redeem recipient's donated amount of sTOC at current index
//         @param depositId_ Deposit id for this donation
//     */
//     function redeemYieldAsStoc(uint256 depositId_) external override {
//         uint256 amountRedeemed = _redeem(depositId_);

//         staking.unwrap(msg.sender, amountRedeemed);
//     }

//     /**
//         @notice Redeem recipient's full donated amount of sTOC at current index as bTOC
//     */
//     function redeemAllYield() external override {
//         uint256 amountRedeemed = _redeemAll();

//         IERC20(bTOC).safeTransfer(msg.sender, amountRedeemed);
//     }

//     /**
//         @notice Redeem recipient's full donated amount of sTOC at current index as bTOC
//     */
//     function redeemAllYieldAsStoc() external override {
//         uint256 amountRedeemed = _redeemAll();

//         staking.unwrap(msg.sender, amountRedeemed);
//     }

//     /************************
//      * Internal Functions
//      ************************/

//     /**
//         @notice Creates a new deposit directing the yield from the deposited bTOC amount
//                 to the prescribed recipient
//         @param amount_ Quantity of bTOC deposited redirecting yield to the recipient
//         @param recipient_ The address of the user who will be entitled to claim the donated yield
//     */
//     function _createDeposit(uint256 amount_, address recipient_) internal returns (uint256 depositId) {
//         if (isInvalidDeposit(amount_, recipient_)) revert YieldDirector_InvalidDeposit();

//         depositId = _deposit(msg.sender, amount_);
//         recipientIds[recipient_].push(depositId);
//         recipientLookup[depositId] = recipient_;

//         emit Deposited(msg.sender, recipient_, amount_);
//     }

//     /**
//         @notice Increases the amount of bTOC directing yield to a recipient
//         @param depositId_ The global ID number of the deposit to add the additional deposit to
//         @param amount_ Quantity of new bTOC deposited redirecting yield to the current deposit's recipient
//     */
//     function _increaseDeposit(uint256 depositId_, uint256 amount_) internal {
//         if (isInvalidUpdate(depositId_, amount_)) revert YieldDirector_InvalidUpdate();

//         _addToDeposit(depositId_, amount_, msg.sender);

//         emit Deposited(depositInfo[depositId_].depositor, recipientLookup[depositId_], amount_);
//     }

//     /**
//         @notice Withdraw bTOC deposit from vault
//         @param depositId_ Deposit ID to remove bTOC deposit from
//         @param amount_ Amount of bTOC deposit to remove and return to donor 
//     */
//     function _withdraw(uint256 depositId_, uint256 amount_) internal returns (uint256 amountWithdrawn) {
//         if (isInvalidWithdrawal(amount_)) revert YieldDirector_InvalidWithdrawal();

//         if (amount_ >= _toAgnostic(depositInfo[depositId_].principalAmount)) {
//             amountWithdrawn = _withdrawAllPrincipal(depositId_, msg.sender);
//         } else {
//             _withdrawPrincipal(depositId_, amount_, msg.sender);
//             amountWithdrawn = amount_;
//         }

//         emit Withdrawn(msg.sender, recipientLookup[depositId_], amountWithdrawn);
//     }

//     /**
//         @notice Redeem available bTOC yield from a specific deposit
//         @param depositId_ Deposit ID to withdraw bTOC yield from
//     */
//     function _redeem(uint256 depositId_) internal returns (uint256 amountRedeemed) {
//         if (redeemDisabled) revert YieldDirector_RedeemsDisabled();
//         if (recipientLookup[depositId_] != msg.sender) revert YieldDirector_NotYourYield();

//         amountRedeemed = _redeemYield(depositId_);

//         if (depositInfo[depositId_].principalAmount == 0) {
//             _closeDeposit(depositId_, depositInfo[depositId_].depositor);

//             uint256[] storage receiptIds = recipientIds[msg.sender];
//             uint256 idsLength = receiptIds.length;

//             for (uint256 i = 0; i < idsLength; ++i) {
//                 if (receiptIds[i] == depositId_) {
//                     // Remove id from recipient's ids array
//                     receiptIds[i] = receiptIds[idsLength - 1]; // Delete integer from array by swapping with last element and calling pop()
//                     receiptIds.pop();
//                     break;
//                 }
//             }

//             delete recipientLookup[depositId_];
//         }

//         emit Redeemed(msg.sender, amountRedeemed);
//         emit Donated(depositInfo[depositId_].depositor, msg.sender, amountRedeemed);
//     }

//     /**
//         @notice Redeem all available bTOC yield from the vault
//     */
//     function _redeemAll() internal returns (uint256 amountRedeemed) {
//         if (redeemDisabled) revert YieldDirector_RedeemsDisabled();

//         amountRedeemed = 0;

//         uint256[] storage receiptIds = recipientIds[msg.sender];

//         // We iterate through the array back to front so that we can delete
//         // elements from the array without changing the locations of any
//         // entries that have not been checked yet
//         for (uint256 index = receiptIds.length; index > 0; index--) {
//             uint256 currRedemption = _redeemYield(receiptIds[index - 1]);
//             amountRedeemed += currRedemption;

//             emit Donated(depositInfo[receiptIds[index - 1]].depositor, msg.sender, currRedemption);

//             if (depositInfo[receiptIds[index - 1]].principalAmount == 0) {
//                 _closeDeposit(receiptIds[index - 1], depositInfo[receiptIds[index - 1]].depositor);

//                 if (index - 1 != receiptIds.length - 1) {
//                     receiptIds[index - 1] = receiptIds[receiptIds.length - 1]; // Delete integer from array by swapping with last element and calling pop()
//                 }

//                 receiptIds.pop();
//             }
//         }

//         emit Redeemed(msg.sender, amountRedeemed);
//     }

//     /************************
//      * Emergency Functions
//      ************************/

//     function emergencyShutdown(bool active_) external onlyGovernor {
//         depositDisabled = active_;
//         withdrawDisabled = active_;
//         redeemDisabled = active_;
//         emit EmergencyShutdown(active_);
//     }

//     function disableDeposits(bool active_) external onlyGovernor {
//         depositDisabled = active_;
//     }

//     function disableWithdrawals(bool active_) external onlyGovernor {
//         withdrawDisabled = active_;
//     }

//     function disableRedeems(bool active_) external onlyGovernor {
//         redeemDisabled = active_;
//     }
// }
