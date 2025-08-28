// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IValidationRegistry.sol";
import "../interfaces/IIdentityRegistry.sol";
import "../interfaces/IValidator.sol";

contract OptimisticMediationValidator is IValidator {
    struct DemandData {
        address mediator;
        uint256 mediationDeadline;
    }

    enum MediationReponse {
        ACCEPTED,
        REJECTED
    }

    error InvalidDemand();
    error DemandAlreadyExists();

    event MediationRequested(
        bytes32 dataHash,
        address mediator,
        uint256 mediationDeadline
    );

    mapping(address => mapping(bytes32 => MediationReponse)) private _responses;

    function mediate(bytes32 dataHash, MediationReponse response) external {
        _responses[msg.sender][dataHash] = response;
    }

    mapping(address => mapping(bytes32 => uint8)) private _mediations;

    IIdentityRegistry public immutable identityRegistry;
    IValidationRegistry public immutable validationRegistry;

    constructor(address _identityRegistry, address _validationRegistry) {
        identityRegistry = IIdentityRegistry(_identityRegistry);
        validationRegistry = IValidationRegistry(_validationRegistry);
    }

    function requestMediation(
        bytes32 dataHash,
        address mediator,
        uint256 mediationDeadline
    ) external {
        emit MediationRequested(dataHash, mediator, mediationDeadline);
    }

    function validate(bytes32 dataHash, bytes memory demand) external {
        DemandData memory demandData = abi.decode(demand, (DemandData));

        if (
            _responses[demandData.mediator][dataHash] ==
            MediationReponse.ACCEPTED
        ) {
            validationRegistry.validationResponse(dataHash, 100);
            return;
        }

        if (
            _responses[demandData.mediator][dataHash] ==
            MediationReponse.REJECTED
        ) {
            validationRegistry.validationResponse(dataHash, 0);
            return;
        }

        if (block.timestamp > demandData.mediationDeadline) {
            // optimistic mediation: accept by default
            validationRegistry.validationResponse(dataHash, 100);
            return;
        }
    }
}
