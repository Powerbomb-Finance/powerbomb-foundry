// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../src/PbProxy.sol";
import "../src/PbCvxSteth.sol";

contract PbCvxStethTest is Test {

    IERC20Upgradeable wbtc = IERC20Upgradeable(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20Upgradeable weth = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Upgradeable usdc = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Upgradeable crv = IERC20Upgradeable(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20Upgradeable cvx = IERC20Upgradeable(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    IERC20Upgradeable seth = IERC20Upgradeable(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    PbCvxSteth vaultUsdc;

    function setUp() public {
        // Deploy implementation contract
        PbCvxSteth vaultImpl = new PbCvxSteth();

        // Deploy usdc reward proxy contract
        PbProxy proxy = new PbProxy(
            address(vaultImpl),
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(uint256,address,address)")),
                25,
                0xDC24316b9AE028F1497c275EB9192a3Ea0f67022,
                address(usdc)
            )
        );
        vaultUsdc = PbCvxSteth(payable(address(proxy)));
    }

    function test() public {
        vaultUsdc.deposit{value: 100 ether}(weth, 100 ether, 0);
        skip(864000);
        deal(address(crv), address(vaultUsdc), 1 ether);
        deal(address(cvx), address(vaultUsdc), 1 ether);
        vaultUsdc.deposit{value: 1 ether}(weth, 1 ether, 0);
        vm.roll(block.number + 1);
        vaultUsdc.withdraw(weth, vaultUsdc.getUserBalance(address(this)), 0);
    }
    
    receive() external payable {}
}