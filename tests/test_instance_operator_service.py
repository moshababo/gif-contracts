import binascii
import brownie
import pytest

from brownie import (
    AccessController,
    InstanceOperatorService
)

from scripts.const import (
    ACCESS_NAME,
    INSTANCE_OPERATOR_SERVICE_NAME,
)

from scripts.util import (
    h2sLeft,
    s2b32,
    contractFromAddress
)

def test_type(instanceOperatorService):
    serviceName = h2sLeft(instanceOperatorService.NAME.call())
    assert INSTANCE_OPERATOR_SERVICE_NAME == serviceName
    assert InstanceOperatorService._name == serviceName


def test_non_existing_functionality(instanceOperatorService, owner):
    with pytest.raises(AttributeError):
        assert instanceOperatorService.foo({'from': owner})


def test_instance_operator_service_contract_in_registry(instanceOperatorService, registry, owner):
    instanceOperatorServiceAddress = registry.getContract(s2b32(INSTANCE_OPERATOR_SERVICE_NAME))

    assert instanceOperatorService.address == instanceOperatorServiceAddress
    assert instanceOperatorService.address != 0x0


def test_role_granting(instance, owner, productOwner, customer):
    registry = instance.getRegistry()
    instanceOperatorServiceAddress = registry.getContract(s2b32(INSTANCE_OPERATOR_SERVICE_NAME))
    instanceOperatorService = contractFromAddress(InstanceOperatorService, instanceOperatorServiceAddress)

    # verify that after setup productOwner account does not yet have product owner role
    poRole = instanceOperatorService.productOwnerRole({'from': customer})
    assert not instanceOperatorService.hasRole(poRole, productOwner, {'from': customer})

    print('owner: {}'.format(owner))
    print('instanceOperatorServiceAddress: {}'.format(instanceOperatorServiceAddress))
    print('productOwner: {}'.format(productOwner))
    print('poRole: {}'.format(poRole))

    # verify that addRoleToAccount is protected and not anybody (ie customer) and grant roles
    with brownie.reverts():
        instanceOperatorService.addRoleToAccount(productOwner, poRole, {'from': customer})

    instanceOperatorService.addRoleToAccount(productOwner, poRole, {'from': owner})

    # verify that productOwner account now has product owner role
    assert instanceOperatorService.hasRole(poRole, productOwner, {'from': customer})


def test_default_admin_role_cannot_be_changed(instance, owner, customer):
    registry = instance.getRegistry()

    accessAddress = registry.getContract(s2b32(ACCESS_NAME))
    access = contractFromAddress(AccessController, accessAddress)

    with brownie.reverts():
        access.setDefaultAdminRole(customer, {'from': owner})

