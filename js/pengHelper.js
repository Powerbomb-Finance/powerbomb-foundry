const ethers = require("ethers")

const ethProvider = new ethers.providers.JsonRpcProvider("https://rpc.ankr.com/eth")
const opProvider = new ethers.providers.JsonRpcProvider("https://rpc.ankr.com/optimism")
const abiCoder = ethers.utils.defaultAbiCoder
const oneEther = ethers.utils.parseEther("1")

const wethAddr = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
const usdcAddr = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

const pengHelperEthAddr = "0x8799c7fEfB44B8c885b489eB38Fb067c75EbA2ab"
const pengHelperOpAddr = "0xCf91CDBB4691a4b912928A00f809f356c0ef30D6"

const poolSusdAddr = "0x061b87122Ed14b9526A813209C8a59a633257bAb"

const sgRouter_ABI = '[{"inputs":[{"internalType":"uint16","name":"_dstChainId","type":"uint16"},{"internalType":"uint8","name":"_functionType","type":"uint8"},{"internalType":"bytes","name":"_toAddress","type":"bytes"},{"internalType":"bytes","name":"_transferAndCallPayload","type":"bytes"},{"components":[{"internalType":"uint256","name":"dstGasForCall","type":"uint256"},{"internalType":"uint256","name":"dstNativeAmount","type":"uint256"},{"internalType":"bytes","name":"dstNativeAddr","type":"bytes"}],"internalType":"struct IStargateRouter.lzTxObj","name":"_lzTxParams","type":"tuple"}],"name":"quoteLayerZeroFee","outputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}]'
const sgRouterEthAddr = "0x8731d54E9D02c286767d56ac03e8037C07e01e98"
const sgRouterEth = new ethers.Contract(sgRouterEthAddr, sgRouter_ABI, ethProvider)
const sgRouterOpAddr = "0xB0D502E938ed5f4df2E681fE6E419ff29631d62b"
const sgRouterOp = new ethers.Contract(sgRouterOpAddr, sgRouter_ABI, opProvider)

const lzEndpointAddr = "0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675"
const lzEndpoint_ABI = ["function estimateFees(uint16, address, bytes calldata, bool, bytes calldata) external view returns (uint)"]
const lzEndpoint = new ethers.Contract(lzEndpointAddr, lzEndpoint_ABI, ethProvider)

const vault_ABI = [
    "function getUserBalanceInUSD(address) external view returns (uint)",
    "function getUserDepositBalance(address) external view returns (uint)",
    "function getUserBalance(address) external view returns (uint)"
]
const vaultSusdAddr = "0x68ca3a3BBD306293e693871E45Fe908C04387614"
const vaultSusd = new ethers.Contract(vaultSusdAddr, vault_ABI, opProvider)
const vaultSethAddr = "0x98f82ADA10C55BC7D67b92d51b4e1dae69eD0250"
const vaultSeth = new ethers.Contract(vaultSethAddr, vault_ABI, opProvider)

const zap_ABI = [
    "function calc_token_amount(address _pool, uint[4] memory _amounts, bool _is_deposit) external view returns (uint)",
    "function calc_withdraw_one_coin(address _pool, uint _token_amount, int128 i) external view returns (uint)",
]
const zapSusdAddr = "0x167e42a1C7ab4Be03764A2222aAC57F5f6754411"
const zapSusd = new ethers.Contract(zapSusdAddr, zap_ABI, opProvider)
const pool_ABI = [
    "function calc_token_amount(uint[2] memory _amounts, bool _is_deposit) external view returns (uint)",
    "function calc_withdraw_one_coin(uint _token_amount, int128 i) external view returns (uint)"
]
const poolSethAddr = "0x7Bc5728BC2b59B45a58d9A576E2Ffc5f0505B35E"
const poolSeth = new ethers.Contract(poolSethAddr, pool_ABI, opProvider)

// amount must > 100 USDC or 0.1 ether after getActualDepositAmount()
const getDepositArgs = async (tokenAddr, amount) => {
    amount = ethers.BigNumber.from(amount)
    let amountOutMin = ethers.constants.Zero
    let value = ethers.constants.Zero
    const gasLimit = 1000000

    if (tokenAddr == usdcAddr) {
        const amountOut = await zapSusd.calc_token_amount(poolSusdAddr, [0, 0, amount, 0], true)
        amountOutMin = amountOut.mul(99).div(100)

        const [fee,] = await sgRouterEth.quoteLayerZeroFee(
            111,
            1,
            ethers.utils.solidityPack(["address"], [pengHelperOpAddr]),
            abiCoder.encode(
                ["address", "address", "uint256"],
                [pengHelperEthAddr, wethAddr, amountOutMin]
            ),
            {dstGasForCall: gasLimit, dstNativeAmount: 0, dstNativeAddr: "0x"}
        )

        value = fee
    }

    if (tokenAddr == wethAddr) {
        const amountOut = await poolSeth.calc_token_amount([amount, 0], true)
        amountOutMin = amountOut.mul(99).div(100)
        
        const [fee,] = await sgRouterEth.quoteLayerZeroFee(
            111,
            1,
            ethers.utils.solidityPack(["address"], [pengHelperOpAddr]),
            abiCoder.encode(
                ["address", "address", "uint256"],
                [pengHelperEthAddr, wethAddr, amountOutMin]
            ),
            {dstGasForCall: gasLimit, dstNativeAmount: 0, dstNativeAddr: "0x"}
        )

        value = (amount.add(fee))
    }

    return {
        token: tokenAddr,
        amount: amount.toString(),
        amountOutMin: amountOutMin.toString(),
        gasLimit: gasLimit.toString(),
        value: value.toString()
    }
}

const getWithdrawArgs = async (token, amountInUsd, userAddr, max=false) => {
    amountInUsd = ethers.BigNumber.from(amountInUsd)
    let amount = ethers.constants.Zero
    let amountOutMin = ethers.constants.Zero
    const gasLimit = 1000000

    if (token == usdcAddr) {
        let withdrawPerc
        
        if (max == true) {
            amount = await vaultSusd.getUserDepositBalance(userAddr)
            withdrawPerc = oneEther

        } else {
            withdrawPerc = amountInUsd.mul(oneEther).div(await vault.getUserDepositBalance(userAddr))
            if (withdrawPerc.gt(oneEther)) withdrawPerc = oneEther
        }

        const userBalanceInLpToken = await vaultSusd.getUserBalance(userAddr)
        const lpTokenAmt = userBalanceInLpToken.mul(withdrawPerc).div(oneEther)
        const amountOut = await zapSusd.calc_withdraw_one_coin(poolSusdAddr, lpTokenAmt, 2)
        amountOutMin = amountOut.mul(99).div(100)
    }

    if (token == wethAddr) {
        let amountInEth
        let withdrawPerc

        if (max == true) {
            amountInEth = await vaultSeth.getUserDepositBalance(userAddr)
            withdrawPerc = oneEther

        } else {
            withdrawPerc = amountInUsd.mul(oneEther).div(await vaultSeth.getUserBalanceInUSD(userAddr))
            if (withdrawPerc.gt(oneEther)) withdrawPerc = oneEther
            amountInEth = (await vaultSeth.getUserDepositBalance(userAddr)).mul(withdrawPerc).div(oneEther)
        }
        amount = amountInEth

        const userBalanceInLpToken = await vaultSeth.getUserBalance(userAddr)
        const lpTokenAmt = userBalanceInLpToken.mul(withdrawPerc).div(oneEther)
        const amountOut = await poolSeth.calc_withdraw_one_coin(lpTokenAmt, 0)
        amountOutMin = amountOut.mul(99).div(100)
    }

    const [nativeForDst,] = await sgRouterOp.quoteLayerZeroFee(
        101,
        1,
        ethers.utils.solidityPack(["address"], [pengHelperEthAddr]),
        [],
        {dstGasForCall: 0, dstNativeAmount: 0, dstNativeAddr: "0x"}
    )

    const fee = await lzEndpoint.estimateFees(
        111,
        pengHelperEthAddr,
        abiCoder.encode(
            ["address", "uint256", "uint256", "address"],
            [token, amount, amountOutMin, userAddr]
        ),
        false,
        ethers.utils.solidityPack(
            ["uint16", "uint256", "uint256", "address"],
            [2, gasLimit, nativeForDst, pengHelperOpAddr]
        )
    )

    return {
        token: token,
        amount: amount.toString(),
        amountOutMin: amountOutMin.toString(),
        gasLimit: gasLimit.toString(),
        nativeForDst: nativeForDst.toString(),
        value: fee.toString()
    }
}

const getActualDepositAmount = amount => {
    amount = ethers.BigNumber.from(amount)
    return amount.sub(amount.mul(6).div(10000)).toString() // 0.06% stargate protocol fee
}

module.exports = {
    getDepositArgs,
    getWithdrawArgs,
    getActualDepositAmount
}

// const test = async () => {
//     // console.log(getActualDepositAmount(ethers.utils.parseUnits("101", 6)))

//     // const args = await getDepositArgs(usdcAddr, ethers.utils.parseUnits("101", 6))
//     // console.log(args.token)
//     // console.log(args.amount)
//     // console.log(args.amountOutMin)
//     // console.log(args.gasLimit)
//     // console.log(args.value)

//     const userAddr = "0x2C10aC0E6B6c1619F4976b2ba559135BFeF53c5E"
//     const args = await getWithdrawArgs(wethAddr, 0, userAddr, true)
//     console.log(args.token)
//     console.log(args.amount)
//     console.log(args.amountOutMin)
//     console.log(args.gasLimit)
//     console.log(args.nativeForDst)
//     console.log(args.value)
// }
// test().catch(err => console.error(err))