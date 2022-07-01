// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@gif-interface/contracts/components/Product.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestProduct is 
    Product 
{
    bytes32 public constant POLICY_FLOW = "PolicyFlowDefault";
    string public constant ORACLE_CALLBACK_METHOD_NAME = "oracleCallback";

    ERC20 private _token;
    address private _capitalOwner;
    address private _feeOwner;
    uint256 private _testOracleId;
    uint256 private _testRiskpoolId;
    uint256 private _policies;
    uint256 private _claims;

    mapping(bytes32 => address) private _policyIdToAddress;
    mapping(bytes32 => uint256) private _policyIdToClaimId;
    mapping(bytes32 => uint256) private _policyIdToPayoutId;

    event LogTestProductFundingReceived(address sender, uint256 amount);
    event LogTestOracleCallbackReceived(uint256 requestId, bytes32 policyId, bytes response);

    modifier onlyPolicyHolder(bytes32 policyId) {
        require(
            _msgSender() == _policyIdToAddress[policyId], 
            "ERROR:TI-1:INVALID_POLICY_OR_HOLDER"
        );
        _;
    }

    constructor(
        bytes32 productName,
        address tokenAddress,
        address capitalOwner,
        address feeOwner, // TODO feeOwner not product specific, move to instance
        uint256 oracleId,
        uint256 riskpoolId,
        address registryAddress
    )
        Product(productName, POLICY_FLOW, registryAddress)
    {
        require(tokenAddress != address(0), "ERROR:TI-2:TOKEN_ADDRESS_ZERO");
        _token = ERC20(tokenAddress);
        _capitalOwner = capitalOwner;
        _feeOwner = feeOwner;
        _testOracleId = oracleId;
        _testRiskpoolId = riskpoolId;
    }

    // TODO remove after switch to token completed
    receive() external payable {
        emit LogTestProductFundingReceived(_msgSender(), msg.value);
    }

    // TODO move function to IProduct / Product
    function getApplicationDataStructure() public view returns(string memory dataStructure) {
        dataStructure = "(address policyHolder, uint256 premium, uint256 sumInsured)";
    }

    // TODO move function to IProduct / Product
    function riskPoolCapacityCallback(uint256 capacity)
        onlyRiskpool
    {
        // whatever product specific logic
    }

    function applyForPolicy(
        uint256 premium, 
        uint256 sumInsured
    ) 
        external 
        payable 
        returns (bytes32 processId) 
    {
        address payable policyHolder = payable(_msgSender());

        // Create and underwrite new application
        processId = keccak256(abi.encode(policyHolder, _policies));
        bytes memory applicationData = abi.encode(
            policyHolder,
            premium, 
            sumInsured
        );

        _newApplication(processId, applicationData);
        _underwrite(processId);

        // Book keeping
        _policyIdToAddress[processId] = policyHolder;
        _policies += 1;
    }

    function expire(bytes32 policyId) 
        external
        onlyOwner
    {
        _expire(policyId);
    }

    function submitClaim(bytes32 policyId, uint256 payoutAmount) 
        external
        onlyPolicyHolder(policyId)
    {

        // increase claims counter
        // the oracle business logic will use this counter value 
        // to determine if the claim is linke to a loss event or not
        _claims += 1;
        
        // claim application
        bytes memory claimsData = abi.encode(payoutAmount);
        uint256 claimId = _newClaim(policyId, claimsData);
        _policyIdToClaimId[policyId] = claimId;

        // Request response to greeting via oracle call
        bytes memory queryData = abi.encode(_claims);
        uint256 requestId = _request(
            policyId,
            queryData,
            ORACLE_CALLBACK_METHOD_NAME,
            _testOracleId
        );
    }

    function oracleCallback(
        uint256 requestId, 
        bytes32 policyId, 
        bytes calldata responseData
    )
        external
        onlyOracle
    {
        emit LogTestOracleCallbackReceived(requestId, policyId, responseData);

        // get oracle response data
        (bool isLossEvent) = abi.decode(responseData, (bool));
        uint256 claimId = _policyIdToClaimId[policyId];

        // claim handling if there is a loss
        if (isLossEvent) {
            // get policy and claims data for oracle response
            (uint256 premium, address payable policyHolder) = abi.decode(
                _getApplicationData(policyId), (uint256, address));

            (uint256 payoutAmount) = abi.decode(
                _getClaimData(policyId, claimId), (uint256));

            // specify payout data
            bytes memory payoutData = abi.encode(payoutAmount);
            uint256 payoutId = _confirmClaim(policyId, claimId, payoutData);
            _policyIdToPayoutId[policyId] = payoutId;

            // create payout record
            bool fullPayout = true;
            _payout(policyId, payoutId, fullPayout, payoutData);

            // actual transfer of funds for payout of claim
            // failing requires not visible when called via .call in querycontroller
            policyHolder.transfer(payoutAmount);
        } else {
            _declineClaim(policyId, claimId);
        }
    }

    function getClaimId(bytes32 policyId) external view returns (uint256) { return _policyIdToClaimId[policyId]; }
    function getPayoutId(bytes32 policyId) external view returns (uint256) { return _policyIdToPayoutId[policyId]; }
    function policies() external view returns (uint256) { return _policies; }
    function claims() external view returns (uint256) { return _claims; }
}