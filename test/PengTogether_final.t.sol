// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "forge-std/Test.sol";
import "../src/PengTogether_final.sol";
import "../src/record.sol";
import "../src/PbProxy.sol";

contract PengTogether_finalTest is Test {
    IERC20Upgradeable weth = IERC20Upgradeable(0x4200000000000000000000000000000000000006);
    IERC20Upgradeable usdc = IERC20Upgradeable(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20Upgradeable lpToken = IERC20Upgradeable(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    IERC20Upgradeable crv = IERC20Upgradeable(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
    IERC20Upgradeable op = IERC20Upgradeable(0x4200000000000000000000000000000000000042);
    // IWETH weth = IWETH(0x4200000000000000000000000000000000000006);
    PengTogether_final vault;
    address owner = 0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E;

    function setUp() public {
        vault = PengTogether_final(payable(0x68ca3a3BBD306293e693871E45Fe908C04387614));
        PengTogether_final vaultImpl = new PengTogether_final();
        hoax(owner);
        vault.upgradeTo(address(vaultImpl));
    }

    function testFinal() public {
        address userAddr = 0xC10fF4C96e9779B5776e7A27Cd3a86C9FB1c1535;
        uint usdcBef = usdc.balanceOf(userAddr);
        uint wethBef = weth.balanceOf(userAddr);
        uint userBalanceInUSD = vault.getUserBalanceInUSD(userAddr);
        // console.log(userBalanceInUSD);

        IVault susdVault = IVault(0xA8e39872452BA48b1F4c7e16b78668199d2C41Dd);
        // harvest first before migrate
        susdVault.harvest();

        // migrate
        hoax(owner);
        vault.migrate(userAddr);
        assertEq(susdVault.getUserBalanceInUSD(userAddr), userBalanceInUSD);

        // assume got reward to claim after migrate
        deal(address(crv), address(susdVault), 1.1 ether);
        hoax(userAddr);
        susdVault.claim();
        assertGt(weth.balanceOf(userAddr), wethBef);

        // withdraw
        uint userBal = susdVault.getUserBalance(userAddr);
        hoax(userAddr);
        susdVault.withdraw(address(usdc), userBal, 0);

        assertGt(usdc.balanceOf(userAddr) - usdcBef, userBalanceInUSD);
    }
}
