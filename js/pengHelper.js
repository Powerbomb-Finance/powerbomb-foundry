const ethers = require("ethers")
const axios = require("axios")

// const ethProvider = new ethers.providers.JsonRpcProvider("https://rpc.ankr.com/eth")
const ethProvider = new ethers.providers.JsonRpcProvider("http://localhost:8546")
// const opProvider = new ethers.providers.JsonRpcProvider("https://rpc.ankr.com/optimism")
const opProvider = new ethers.providers.JsonRpcProvider("http://localhost:8545")
const abiCoder = ethers.utils.defaultAbiCoder
const oneEther = ethers.utils.parseEther("1")

const wethAddr = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
const usdcAddr = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

const pengHelperEthAddr = "0x8799c7fEfB44B8c885b489eB38Fb067c75EbA2ab"
const pengHelperEth_ABI = [
  "function deposit(address token, uint amount, uint amountOutMin, uint gasLimit) external payable",
  "function withdraw(address token, uint amount, uint amountOutMin, uint gasLimit, uint nativeForDest) external payable"
]
const pengHelperEth = new ethers.Contract(pengHelperOpAddr, pengHelperEth_ABI, ethProvider)
const pengHelperOpAddr = "0xCf91CDBB4691a4b912928A00f809f356c0ef30D6"
const pengHelperOp_ABI = [
  "function switchVault(address fromVaultAddr, address toVaultAddr, uint amountWithdraw, uint amountToSwap, uint[] memory amountsOutMin, bytes memory data) external"
]
const pengHelperOp = new ethers.Contract(pengHelperOpAddr, pengHelperOp_ABI, opProvider)

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
const getDepositArgs = async (tokenAddr, amount, userAddr) => {
  amount = ethers.BigNumber.from(amount)
  let amountOutMin = ethers.constants.Zero
  let value = ethers.constants.Zero
  // gas limit for calling sgReceive() on optimism by stargate
  const gasLimit = 1000000

  if (tokenAddr == usdcAddr) {
    // get estimate amount out after deposit (on optimism side)
    // [0, 0, amount, 0] = [susd, usdt, usdc, dai]
    // use zap to calculate amount out (as well as deposit) because susd pool only accept susd & 3crv
    const amountOut = await zapSusd.calc_token_amount(poolSusdAddr, [0, 0, amount, 0], true)
    // calculate amount out min for deposit, 1% slippage
    amountOutMin = amountOut.mul(99).div(100)

    // quote gas fee to bridge token from ethereum to optimism pengHelperOp contract
    const [fee,] = await sgRouterEth.quoteLayerZeroFee(
      111, // uint16 _dstChainId
      1, // uint8 _functionType
      ethers.utils.solidityPack(["address"], [pengHelperOpAddr]), // bytes calldata _toAddress
      abiCoder.encode(
        // [depositor wallet address, deposit token, amount out minimum for deposit on optimism side]
        ["address", "address", "uint256"],
        [userAddr, usdcAddr, amountOutMin]
      ), // bytes calldata _transferAndCallPayload
      { dstGasForCall: gasLimit, dstNativeAmount: 0, dstNativeAddr: "0x" } // Router.lzTxObj memory _lzTxParams
    )

    // eth pass alongside with deposit() = gas fee above
    value = fee
  }

  if (tokenAddr == wethAddr) {
    // get estimate amount out after deposit (on optimism side)
    // [amount, 0] = [native eth, seth token]
    const amountOut = await poolSeth.calc_token_amount([amount, 0], true)
    // calculate amount out min for deposit, 1% slippage
    amountOutMin = amountOut.mul(99).div(100)

    // quote gas fee to bridge token from ethereum to optimism pengHelperOp contract
    const [fee,] = await sgRouterEth.quoteLayerZeroFee(
      111, // uint16 _dstChainId
      1, // uint8 _functionType
      ethers.utils.solidityPack(["address"], [pengHelperOpAddr]),
      abiCoder.encode(
        // [depositor wallet address, deposit token, amount out minimum for deposit on optimism side]
        ["address", "address", "uint256"],
        [userAddr, wethAddr, amountOutMin]
      ), // bytes calldata _transferAndCallPayload
      { dstGasForCall: gasLimit, dstNativeAmount: 0, dstNativeAddr: "0x" } // Router.lzTxObj memory _lzTxParams
    )

    // eth pass alongside with deposit() = deposit amount + gas fee above
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
  let amountWithdraw = ethers.constants.Zero
  let amountOutMin = ethers.constants.Zero
  // gas limit for calling lzReceive() on optimism by layerzero
  const gasLimit = 1000000

  if (token == usdcAddr) {
    // get user balance of lp token
    const userBalance = await vaultSusd.getUserBalance(userAddr)
    // get user deposit balance of usd
    const userDepositBalance = await vaultSusd.getUserDepositBalance(userAddr)
    let lpTokenAmt

    if (max == true) {
      // input amount in usd = user all deposit balance of usd
      amountInUsd = userDepositBalance
      // lp token amount to withdraw = user all balance of lp token
      lpTokenAmt = userBalance

    } else {
      // calculate user balance of lp token
      lpTokenAmt = amountInUsd.mul(userBalance).div(userDepositBalance)
    }

    // get estimation for usdc withdraw from poolSusd
    const estimateAmountOutUsdc = await zapSusd.calc_withdraw_one_coin(poolSusdAddr, lpTokenAmt, 2)
    // calculate amount out minimum withdraw, % slippage
    amountOutMin = estimateAmountOutUsdc.mul(99).div(100)
    // amount to pass into vaultSusd = amountInUsd in function parameter above
    amountWithdraw = amountInUsd
  }

  if (token == wethAddr) {
    // get user balance of lp token
    const userBalance = await vaultSeth.getUserBalance(userAddr)
    // get user deposit balance of eth
    const userDepositBalance = await vaultSeth.getUserDepositBalance(userAddr)
    // vaultSeth input token amount is amount in eth
    let amountInEth
    let lpTokenAmt

    if (max == true) {
      // input amount in eth = user all deposit balance of eth
      amountInEth = userDepositBalance
      // lp token amount to withdraw = user all balance of lp token
      lpTokenAmt = userBalance

    } else {
      // get user balance in usd, convert from amountInUsd to amountInEth
      let withdrawPerc = amountInUsd.mul(oneEther).div(await vaultSeth.getUserBalanceInUSD(userAddr))
      // to prevent withdrawPerc > oneEther
      if (withdrawPerc.gt(oneEther)) withdrawPerc = oneEther
      // calculate user deposit balance of eth with withdrawPerc above
      amountInEth = userDepositBalance.mul(withdrawPerc).div(oneEther)
      // calculate user balance of lp token with amountInEth above
      lpTokenAmt = amountInEth.mul(userBalance).div(userDepositBalance)
    }

    // get estimation for eth withdraw from poolSeth
    const estimateAmountOutEth = await poolSeth.calc_withdraw_one_coin(lpTokenAmt, 0)
    // calculate amount out minimum withdraw, % slippage
    amountOutMin = estimateAmountOutEth.mul(99).div(100)
    // amount to pass into vaultSeth = amount in eth calculate above
    amountWithdraw = amountInEth
  }

  // quote gas fee to bridge token from optimism to ethereum user wallet address
  const [nativeForDst,] = await sgRouterOp.quoteLayerZeroFee(
    101, // uint16 _dstChainId
    1, // uint8 _functionType
    ethers.utils.solidityPack(["address"], [userAddr]), // bytes calldata _toAddress
    [], // bytes calldata _transferAndCallPayload
    { dstGasForCall: 0, dstNativeAmount: 0, dstNativeAddr: "0x" } // Router.lzTxObj memory _lzTxParams
  )

  // estimate gas fee for calling lzReceive() on optimism side
  const fee = await lzEndpoint.estimateFees(
    111, // the destination LayerZero chainId
    pengHelperEthAddr, // contract address that calls Endpoint.send()
    abiCoder.encode(
      ["address", "uint256", "uint256", "address"],
      [token, amountWithdraw, amountOutMin, userAddr]
    ), // payload
    false, // _payInZRO
    ethers.utils.solidityPack(
      // [version, gasAmount, nativeForDst, addressOnDst]
      ["uint16", "uint256", "uint256", "address"],
      [2, gasLimit, nativeForDst, pengHelperOpAddr]
    ) // v2 adapterParams, encoded for version 2 style
    // which can instruct the LayerZero message to give 
    // destination nativeForDst wei of native gas into pengHelperOpAddr
  )

  return {
    token: token,
    amount: amountWithdraw.toString(),
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

const getSwitchVaultArgs = async (fromVaultAddr, toVaultAddr, userAddr, amountInUsd, max=false) => {
  amountInUsd = ethers.BigNumber.from(amountInUsd)
  const ethAddr = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
  const usdcAddr = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"

  // variables to pass into vault contract
  let amountWithdraw = ethers.constants.Zero
  let amountToSwap = ethers.constants.Zero
  let amountOutMinWithdraw = ethers.constants.Zero
  let amountOutMinDeposit = ethers.constants.Zero
  let data

  if (fromVaultAddr == vaultSusdAddr && toVaultAddr == vaultSethAddr) {
    // get user balance of lp token
    const userBalance = await vaultSusd.getUserBalance(userAddr)
    // get user deposit balance of usd
    const userDepositBalance = await vaultSusd.getUserDepositBalance(userAddr)
    let lpTokenAmt

    if (max == true) {
      // input amount in usd = user all deposit balance of usd
      amountInUsd = userDepositBalance
      // lp token amount to withdraw = user all balance of lp token
      lpTokenAmt = userBalance
    } else {
      // calculate user balance of lp token
      lpTokenAmt = amountInUsd.mul(userBalance).div(userDepositBalance)
    }
    // get estimation for usdc withdraw from poolSusd
    const estimateAmountOutUsdc = await zapSusd.calc_withdraw_one_coin(poolSusdAddr, lpTokenAmt, 2)
    // calculate amount out minimum withdraw, % slippage
    amountOutMinWithdraw = estimateAmountOutUsdc.mul(99).div(100)
    // amount usdc to swap with paraswap = amount out minimum withdraw
    // because we don't know how much the actual withdraw
    // so this is just an estimation to prevent paraswap swap error
    const amountUsdcToSwap = amountOutMinWithdraw
    // for return variable
    amountToSwap = amountUsdcToSwap
    // amount to pass into vaultSusd = amountInUsd in function parameter above
    amountWithdraw = amountInUsd

    const srcToken = usdcAddr
    const destToken = ethAddr

    // get priceRoute from paraswap to build paraswap transaction data
    let res = await axios.get(
      `https://apiv5.paraswap.io/prices` +
      `?srcToken=${srcToken}` +
      `&destToken=${destToken}` +
      `&amount=${amountUsdcToSwap.toString()}` +
      `&network=10` +
      `&userAddress=${pengHelperOpAddr}`
    )
    const priceRoute = res.data.priceRoute
    const estimateEthSwap = ethers.BigNumber.from(priceRoute.destAmount)
    // get amount out minimum deposit from estimate eth received from priceRoute above, % slippage
    amountOutMinDeposit = estimateEthSwap.mul(99).div(100)

    // get transaction data from paraswap
    res = await axios.post(
      `https://apiv5.paraswap.io/transactions/10` +
      `?ignoreChecks=true`,
      {
        srcToken: srcToken,
        destToken: destToken,
        srcAmount: amountUsdcToSwap.toString(),
        priceRoute: priceRoute,
        slippage: 50, // 0.5% usdc -> eth
        userAddress: pengHelperOpAddr
      }
    )
    data = res.data.data

  } else if (fromVaultAddr == vaultSethAddr && toVaultAddr == vaultSusdAddr) {
    // get user balance of lp token
    const userBalance = await vaultSeth.getUserBalance(userAddr)
    // get user deposit balance of eth
    const userDepositBalance = await vaultSeth.getUserDepositBalance(userAddr)
    // vaultSeth input token amount is amount in eth
    let amountInEth
    let lpTokenAmt

    if (max == true) {
      // input amount in eth = user all deposit balance of eth
      amountInEth = userDepositBalance
      // lp token amount to withdraw = user all balance of lp token
      lpTokenAmt = userBalance

    } else {
      // get user balance in usd, convert from amountInUsd to amountInEth
      let withdrawPerc = amountInUsd.mul(oneEther).div(await vaultSeth.getUserBalanceInUSD(userAddr))
      // to prevent withdrawPerc > oneEther
      if (withdrawPerc.gt(oneEther)) withdrawPerc = oneEther
      // calculate user deposit balance of eth with withdrawPerc above
      amountInEth = userDepositBalance.mul(withdrawPerc).div(oneEther)
      // calculate user balance of lp token with amountInEth above
      lpTokenAmt = amountInEth.mul(userBalance).div(userDepositBalance)
    }
    
    // get estimation for eth withdraw from poolSeth
    const estimateAmountOutEth = await poolSeth.calc_withdraw_one_coin(lpTokenAmt, 0)
    // calculate amount out minimum withdraw, % slippage
    amountOutMinWithdraw = estimateAmountOutEth.mul(99).div(100)
    // amount eth to swap with paraswap = amount out minimum withdraw
    // because we don't know how much the actual withdraw
    // so this is just an estimation to prevent paraswap swap error
    const amountEthToSwap = amountOutMinWithdraw
    // for return variable
    amountToSwap = amountEthToSwap
    // amount to pass into vaultSeth = amount in eth calculate above
    amountWithdraw = amountInEth

    const srcToken = ethAddr
    const destToken = usdcAddr

    // get priceRoute from paraswap to build paraswap transaction data
    let res = await axios.get(
      `https://apiv5.paraswap.io/prices` +
      `?srcToken=${srcToken}` +
      `&destToken=${destToken}` +
      `&amount=${amountEthToSwap.toString()}` +
      `&network=10` +
      `&userAddress=${pengHelperOpAddr}`
    )
    const priceRoute = res.data.priceRoute
    const estimateUsdcSwap = ethers.BigNumber.from(priceRoute.destAmount)
    // get amount out minimum deposit from estimate usdc received from priceRoute above, % slippage
    amountOutMinDeposit = estimateUsdcSwap.mul(99).div(100)

    // get transaction data from paraswap
    res = await axios.post(
      `https://apiv5.paraswap.io/transactions/10` +
      `?ignoreChecks=true`,
      {
        srcToken: srcToken,
        destToken: destToken,
        srcAmount: amountEthToSwap.toString(),
        priceRoute: priceRoute,
        slippage: 50, // 0.5% eth -> usdc
        userAddress: pengHelperOpAddr
      }
    )
    data = res.data.data
  }

  return {
    fromVaultAddr: fromVaultAddr,
    toVaultAddr: toVaultAddr,
    amountWithdraw: amountWithdraw.toString(),
    amountToSwap: amountToSwap.toString(),
    amountsOutMin: [amountOutMinWithdraw.toString(), amountOutMinDeposit.toString()],
    data: data
  }
}

module.exports = {
  getDepositArgs,
  getWithdrawArgs,
  getActualDepositAmount,
  getSwitchVaultArgs
}

const test = async () => {
  // getActualDepositAmount(): actual deposit amount after bridge to optimism
  // actual deposit amount = deposit amount - stargate protocol fee (0.06%)
  // actual deposit amount must > 100 USDC or 0.1 ether, else deposit will failed on optimism side
  // usdc example
  const actualDepositUsdc = getActualDepositAmount(ethers.utils.parseUnits("101", 6))
  // console.log(actualDepositUsdc) // 100939400
  // eth example
  const actualdepositEth = getActualDepositAmount(ethers.utils.parseEther("1.01"))
  // console.log(actualdepositEth) // 1009394000000000000

  const userAddr = "0x..."

  // deposit usdc example
  const depositArgsUsdc = await getDepositArgs(usdcAddr, ethers.utils.parseUnits("101", 6), userAddr)
  await usdc.approve(pengHelperEthAddr, ethers.constants.MaxUint256)
  await pengHelperEth.deposit(
      depositArgsUsdc.token,
      depositArgsUsdc.amount,
      depositArgsUsdc.amountOutMin,
      depositArgsUsdc.gasLimit,
      {value: depositArgsUsdc.value}
  )

  // deposit eth example
  const depositArgsEth = await getDepositArgs(wethAddr, ethers.utils.parseEther("0.11"), userAddr)
  await pengHelperEth.deposit(
      depositArgsEth.token,
      depositArgsEth.amount,
      depositArgsEth.amountOutMin,
      depositArgsEth.gasLimit,
      {value: depositArgsEth.value}
  )

  // withdraw usdc example
  const withdrawArgsUsdc = await getWithdrawArgs(usdcAddr, ethers.utils.parseUnits("100", 6), userAddr, false)
  await pengHelperEth.withdraw(
      withdrawArgsUsdc.token,
      withdrawArgsUsdc.amount,
      withdrawArgsUsdc.amountOutMin,
      withdrawArgsUsdc.gasLimit,
      withdrawArgsUsdc.nativeForDst,
      {value: withdrawArgsUsdc.value}
  )

  // withdraw eth example
  const withdrawArgsEth = await getWithdrawArgs(wethAddr, ethers.utils.parseUnits("100", 6), userAddr, false)
  await pengHelperEth.withdraw(
      withdrawArgsEth.token,
      withdrawArgsEth.amount,
      withdrawArgsEth.amountOutMin,
      withdrawArgsEth.gasLimit,
      withdrawArgsEth.nativeForDst,
      {value: withdrawArgsEth.value}
  )

  // switch vault example
  const switchVaultArgs = await getSwitchVaultArgs(
    vaultSethAddr,
    vaultSusdAddr,
    userAddr,
    ethers.utils.parseUnits("101", 6),
    false
  )
  await pengHelperOp.switchVault(
    switchVaultArgs.fromVaultAddr,
    switchVaultArgs.toVaultAddr,
    switchVaultArgs.amountWithdraw,
    switchVaultArgs.amountToSwap,
    switchVaultArgs.amountsOutMin,
    switchVaultArgs.data
  )
}
test().catch(err => console.error(err))