// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IDelegateRegistry} from "src/IDelegateRegistry.sol";

import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Identity
 * @notice A contract for symmetric clustering of wallet addresses
 */

/**
TODO:
how will we define a clustering?
- by a specific cluster id, that's linked to a namespace
- it's an enumerableset of wallets
how do people add or remove themselves from the cluster?

what does it look like to have a gaming guild as a cluster?
give an NFT to all members of the cluster, maybe 1155
does this end up looking like a multisig? 2/3 approval, etc
seems kinda dangerous to delegate an entire cluster, makes it riskier to join
 */

contract Identity {
    using EnumerableSet for EnumerableSet.AddressSet;

    IDelegateRegistry public immutable delegateRegistry;

    uint256 clusterCount = 0;

    mapping(uint256 clusterId => EnumerableSet.AddressSet members) internal clusterMembers;
    mapping(uint256 clusterId => string name) public clusterNames;
    mapping(uint256 clusterId => EnumerableSet.AddressSet invitedMembers) internal clusterInvitedMembers;

    /// @param registry_ is the address of the v2 delegation registry contract.
    constructor(address registry_) {
        delegateRegistry = IDelegateRegistry(registry_);
    }

    function createCluster(string memory name) external {
        clusterNames[clusterCount] = name;
        clusterMembers[clusterCount].add(msg.sender);
        clusterCount++;
    }

    // TODO: batch invites
    function inviteToCluster(uint256 clusterId, address invitedMember) public {
        require(clusterMembers[clusterId].contains(msg.sender), "must be in cluster to invite others");
        require(!clusterInvitedMembers[clusterId].contains(invitedMember), "already invited");
        clusterInvitedMembers[clusterId].add(invitedMember);
    }

    // TODO: batch acceptances with EIP-712 sigs
    function acceptInvitation(uint256 clusterId) public {
        require(clusterInvitedMembers[clusterId].contains(msg.sender), "not invited");
        clusterInvitedMembers[clusterId].remove(msg.sender);
        clusterMembers[clusterId].add(msg.sender);
    }
}
