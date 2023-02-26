// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import "./SuperAppBaseFlow.sol";

import { IERC1820Registry } from "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";
import { IERC777Recipient } from "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";

import "hardhat/console.sol";

/// @title Debt Repay 
/// @author Kobuta23
contract DebtRepay is SuperAppBaseFlow, IERC777Recipient {

    /// @notice Importing the SuperToken Library to make working with streams easy.
    using SuperTokenV1Library for ISuperToken;
    // ---------------------------------------------------------------------------------------------
    // STORAGE & IMMUTABLES

    /// @notice Constant used for ERC777.

    IERC1820Registry constant internal _ERC1820_REG = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    /// @notice Token coming in and token going out
    ISuperToken public immutable cashToken;

    address public owner;
    address public debtHolder;

    uint256 public debtTotal;
    uint256 public debtInterestRate;
    uint256 public revenueShare; // percentage of income to repay debt. Scaled 1:10'000 (0.01%)

    uint256 internal repaidAmountTally; // incomplete, use function repaidAmount for precise value

    constructor(
        ISuperToken _cashToken, // super token to be used
        address _owner
    ) SuperAppBaseFlow(
        ISuperfluid(_cashToken.getHost()), 
        true, 
        true, 
        true
    ) {
        cashToken = _cashToken;
        owner = _owner;
        _acceptedSuperTokens[_cashToken] = true;

        bytes32 erc777TokensRecipientHash = keccak256("ERC777TokensRecipient");
        _ERC1820_REG.setInterfaceImplementer(address(this), erc777TokensRecipientHash, address(this));
    }

    // ---------------------------------------------------------------------------------------------
    // UTILITY FUNCTIONS
    // ---------------------------------------------------------------------------------------------

    function repaidAmount() public returns (uint256){
        // calculates how much has been repaid so far
        (uint256 timestamp, int96 flowRate,,) = cashToken.getFlowInfo(address(this), debtHolder); // should get timestamp and also flowRate
        return _repaidAmount(timestamp, flowRate);
    }
    
    function _repaidAmount(uint256 timestamp, int96 flowRate) internal returns (uint256){
        // internal function that can take "previous" values
        return repaidAmountTally + uint256(int256(flowRate)) * (block.timestamp - timestamp);
    }

    function settleTally() internal {
        (uint256 timestamp, int96 flowRate,,) = cashToken.getFlowInfo(address(this), debtHolder); // should get timestamp and also flowRate
        repaidAmountTally = _repaidAmount(timestamp, flowRate);
    }

    function settleTally(uint256 timestamp, int96 flowRate) internal {
        repaidAmountTally = _repaidAmount(timestamp, flowRate);
    }

    function adjustStreams(int96 oldFlowRateOwner, int96 oldFlowRateDebtHolder, bytes memory ctx) internal returns (bytes memory newCtx) {
        // adjust up or down based on app netflow
        int96 flowRateDelta = cashToken.getNetFlowRate(address(this));   
        int96 debtFlowRateDelta = flowRateDelta * int96(int256(revenueShare));
        int96 ownerFlowRateDelta = flowRateDelta - debtFlowRateDelta; 
        newCtx = ctx;
        
        if(debtFlowRateDelta > 0){
            // increase outflow
            if(oldFlowRateDebtHolder > 0) {
                // updateFlowWithCtx
                newCtx = cashToken.updateFlowWithCtx(debtHolder, debtFlowRateDelta + oldFlowRateDebtHolder, newCtx);
                newCtx = cashToken.updateFlowWithCtx(owner, ownerFlowRateDelta + oldFlowRateOwner, newCtx);
            } else {
                // createFlow
                newCtx = cashToken.createFlowWithCtx(debtHolder, debtFlowRateDelta, newCtx);
                newCtx = cashToken.createFlowWithCtx(owner, ownerFlowRateDelta, newCtx);
            }
        } else {
            // decrease outflow
            if(oldFlowRateDebtHolder > -debtFlowRateDelta){
                // update
                newCtx = cashToken.updateFlowWithCtx(debtHolder, oldFlowRateDebtHolder + debtFlowRateDelta, newCtx);
                newCtx = cashToken.updateFlowWithCtx(owner, oldFlowRateOwner + ownerFlowRateDelta, newCtx);
            } else {
                // delete
                newCtx = cashToken.deleteFlowWithCtx(address(this), debtHolder, newCtx);
                newCtx = cashToken.deleteFlowWithCtx(address(this), owner, newCtx);
            }
        }

    }

    // ---------------------------------------------------------------------------------------------
    // ISSUING DEBT
    // ---------------------------------------------------------------------------------------------

    // we can make it an NFT (adding transferability) later
    function issueDebt(uint256 amount, address holder, uint256 share) public {
        require(msg.sender == owner, "Only owner can issue debt");
        // check current status first. If debt already out there, shouldn't be issuable to new party (even by owner!)
        require(debtTotal == 0, "There is still debt owed");
        debtTotal = amount;
        debtHolder = holder;
        revenueShare = share;
    }

    function clearDebt() public {
        require(repaidAmount() >= debtTotal, "debt not repaid");
        debtTotal = 0;
        debtHolder = address(0);
        revenueShare = 0;
        repaidAmountTally = 0;
        int96 flowrateDebt = cashToken.getFlowRate(address(this), debtHolder);
        int96 flowrateOwner = cashToken.getFlowRate(address(this), owner);
        cashToken.deleteFlow(address(this), debtHolder);
        cashToken.updateFlow(owner, flowrateDebt + flowrateOwner);
    }

    // ---------------------------------------------------------------------------------------------
    // SUPER APP CALLBACKS
    // ---------------------------------------------------------------------------------------------

    // IERC777Recipient
    function tokensReceived(
        address /*operator*/,
        address from,
        address /*to*/,
        uint256 amount,
        bytes calldata /*userData*/,
        bytes calldata /*operatorData*/
    ) override external {
        // if it's not a SuperToken, something will revert along the way
        require(ISuperToken(msg.sender) == cashToken, "Please send the right token!");
        // send funds following same split
        // adjust tally accordingly
        uint256 repayAmount = amount * revenueShare / 10000;
        repaidAmountTally += repayAmount;
        cashToken.transfer(debtHolder, repayAmount);
        cashToken.transfer(owner, amount - repayAmount);
    }

    /// @dev super app callback triggered after user sends stream to contract
    function afterFlowCreated(
        ISuperToken /*superToken*/,
        address /*sender*/,
        bytes calldata /*beforeData*/,
        bytes calldata ctx
    ) internal override returns (bytes memory) {
        return doThings(ctx);
    }

    function afterFlowUpdated(
        ISuperToken /*superToken*/,
        address /*sender*/,
        bytes calldata /*beforeData*/,
        bytes calldata ctx
    ) internal override returns (bytes memory) {
        return doThings(ctx);
    }

    function afterFlowDeleted(
        ISuperToken /*superToken*/,
        address sender,
        address receiver,
        bytes calldata beforeData,
        bytes calldata ctx
    ) internal override returns (bytes memory) {
        if(sender == address(this)) {
            // either the owner or the debtHolder cancelled their stream
            // we will reopen it immediately
            // if it's the debt holder we'll also settle
            (uint256 oldTimeStamp, int96 oldFlowRate) = abi.decode(beforeData, (uint256, int96));
            if(receiver == debtHolder) settleTally(oldTimeStamp, oldFlowRate);
            return cashToken.createFlowWithCtx(receiver, oldFlowRate, ctx);
        }
        return doThings(ctx);
    }

    function doThings(bytes memory ctx) internal returns (bytes memory newCtx){
        (uint256 timestamp, int96 oldFlowRateDebtHolder,,) = cashToken.getFlowInfo(address(this), debtHolder); // should get timestamp and also flowRate
        settleTally(timestamp, oldFlowRateDebtHolder);
        newCtx = adjustStreams(cashToken.getFlowRate(address(this), owner), oldFlowRateDebtHolder, ctx);
    }
}
