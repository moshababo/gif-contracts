from scripts.instance import GifInstance

from scripts.product import (
    GifTestOracle,
    GifTestProduct,
)

def test_deploy(instance: GifInstance, oracleOwner, productOwner):
    ios = instance.getInstanceOperatorService()

    assert ios.oracleTypes() == 0
    assert ios.oracles() == 0
    assert ios.products() == 0

    oracle = GifTestOracle(instance, oracleOwner)

    assert ios.oracleTypes() == 1
    assert ios.oracles() == 1
    assert ios.products() == 0

    product = GifTestProduct(instance, oracle, productOwner)

    assert ios.oracleTypes() == 1
    assert ios.oracles() == 1
    assert ios.products() == 1