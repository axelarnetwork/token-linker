
// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { VersionManagement } from '../libraries/VersionManagement.sol';
import { IVersionManaged } from '../interfaces/IVersionManaged.sol';

abstract contract VersionManaged is IVersionManaged{
    using VersionManagement for bytes32;

    // uint256(keccak256('version-management-slot')) - 1;
    uint256 public constant VERSION_MANAGEMENT_SLOT = 0x776e4712c554364c76a0a9e44e8ed812e87e704043156479229febd5cfcffc66;

    function getVersionManagement() public view override returns(bytes32 vm) {
        assembly {
            vm := sload(VERSION_MANAGEMENT_SLOT)
        }
    }
    function _setVersionManagement(bytes32 vm) internal {
        assembly {
            sstore(VERSION_MANAGEMENT_SLOT, vm)
        }
    }
        
    function getCurrentVersion() public view override returns(uint256 currentVersion) {
        currentVersion = getVersionManagement().getVersion();
    }

    function _setVersion(uint256 newVersion) internal {
        bytes32 vm = getVersionManagement();
        vm = VersionManagement.getVersionManagement(vm.isFactoryManaged(), newVersion);
        _setVersionManagement(vm);
    }
}

