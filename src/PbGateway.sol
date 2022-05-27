// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "oz-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "oz-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "oz-upgradeable/security/PausableUpgradeable.sol";
import "oz-upgradeable/proxy/utils/Initializable.sol";
import "oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./lib/NonblockingLzApp.sol";
import "./interfaces/IPbFarm.sol";
import "./interfaces/IPbState.sol";
import "./interfaces/IBridge.sol";

contract PbGateway is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, NonblockingLzApp {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public USDT;
    IERC20Upgradeable public USDC;
    IPbFarm public pbFarm;
    IPbState public pbState;
    IBridge public bridge;
    mapping(address => uint) internal depositedBlock;
    
    // for pending withdrawal
    struct WithdrawInfo {
        IERC20Upgradeable token;
        uint amount;
        uint initializeTimestamp;
    }
    mapping(address => WithdrawInfo) public pendingWithdraw;

    // for LayerZero payload record & farm
    enum RecordType { DEPOSIT, WITHDRAW, CLAIM }
    enum FarmType { HARVEST, REPAY }
    enum GatewayType { REPAY }

    event Deposit(address token, uint amount, uint farmChain);
    event Withdraw(address token, uint amount);
    event RequestWithdraw(address account, address token, uint amount);
    event RepayWithdraw(address account, uint amount);

    function initialize(
        IERC20Upgradeable _USDT,
        IERC20Upgradeable _USDC,
        IPbFarm _pbFarm,
        IPbState _pbState,
        ILayerZeroEndpoint _endpoint,
        IBridge _bridge
    ) external initializer {
        __Ownable_init();

        USDT = _USDT;
        USDC = _USDC;
        pbFarm = _pbFarm;
        pbState = _pbState;
        lzEndpoint = _endpoint;
        bridge = _bridge;
    }

    function deposit(
        IERC20Upgradeable token,
        uint amount,
        uint chainId,
        address farmAddr,
        address rewardToken
    ) external payable nonReentrant whenNotPaused {
        require(token == USDT || token == USDC, "Invalid token");
        // Due to the fees of Synapse bridge, minimum $20 deposit 
        require(amount >= 20e6, "Minimum 20 USD deposit");

        token.safeTransferFrom(msg.sender, address(this), amount);
        depositedBlock[msg.sender] = block.number;

        if (pbFarm.isFarm()) {
            // pbFarm is in same chain
            pbFarm.deposit(address(token), amount);
        } else {
            // bridge token to pbFarm in corresponding chain
            bridge.deposit(farmAddr, chainId, address(token), amount);
        }

        if (block.chainid == 43114) {
            // on Avalanche, record directly into pbState
            pbState.recordDeposit(msg.sender, amount, rewardToken);
        } else {
            // on other chain, use LayerZero to record into pbState in Avalanche
            _lzSend(
                6, // Avalanche chain id of LayerZero
                abi.encode(msg.sender, amount, rewardToken, block.chainid, RecordType.DEPOSIT),
                payable(msg.sender),
                address(0),
                bytes("")
            );
        }

        emit Deposit(address(token), amount, chainId);
    }

    function withdraw(IERC20Upgradeable token, uint amount) external payable nonReentrant {
        require(token == USDT || token == USDC, "Invalid token");
        // Due to the fees of Synapse bridge, minimum $20 withdrawal 
        require(amount >= 20e6, "Minimum 20 USD withdrawal");

        if (pbFarm.isFarm()) {
            // pbFarm is in same chain
            pbFarm.withdraw(address(token), amount);
            token.safeTransfer(msg.sender, amount);
        } else {
            // record withdraw details & emit request withdraw event
            WithdrawInfo storage info = pendingWithdraw[msg.sender];
            info.token = token;
            info.amount = amount;
            info.initializeTimestamp = block.timestamp;
            emit RequestWithdraw(msg.sender, address(token), amount);
        }

        if (block.chainid == 43114) {
            // on Avalanche, record directly into pbState
            pbState.recordWithdraw(msg.sender, amount);
        } else {
            // on other chain, use LayerZero to record into pbState in Avalanche
            _lzSend(
                6, // Avalanche chain id of LayerZero
                abi.encode(msg.sender, amount, address(0), block.chainid, RecordType.WITHDRAW),
                payable(msg.sender),
                address(0),
                bytes("")
            );
        }

        emit Withdraw(address(token), amount);
    }

    /// @notice This function is for manual repay withdraw if never receive withdraw after 1 hour
    /// @param lzChainId LayerZero chainId for current farm
    function repayWithdraw(address account, uint16 lzChainId, address farm) external payable {
        WithdrawInfo memory info = pendingWithdraw[msg.sender];
        require(info.amount > 0, "Nothing to withdraw");
        require(info.initializeTimestamp + 1 hours < block.timestamp, "Pending withdrawal period");

        delete pendingWithdraw[account];
        
        lzEndpoint.send{value: msg.value}(
            lzChainId,
            abi.encodePacked(farm),
            abi.encode(msg.sender, info.amount, RecordType.WITHDRAW),
            payable(msg.sender),
            address(0),
            bytes("")
        );

        emit RepayWithdraw(account, info.amount);
    }

    /// @notice Supported reward token send from pbState to msg.sender
    function claimReward() external payable {
        _lzSend(
            6, // Avalanche chain id of LayerZero
            abi.encode(msg.sender, 0, address(0), block.chainid, RecordType.CLAIM),
            payable(msg.sender),
            address(0),
            bytes("")
        );
    }

    /// @notice use by pbFarm to delete pendingWithdraw after repay withdraw
    /// @notice withdraw amount send directly from pbFarm
    /// @notice actual withdraw amount might different from pendingWithdraw[account].amount due to fees by Synapse bridge
    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory data) internal override {
        (address account, uint amount) =  abi.decode(data, (address, uint));
        require(pendingWithdraw[account].amount == amount, "RepayWithdraw: not good"); // Sanity check
        delete pendingWithdraw[account];
        emit RepayWithdraw(account, amount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
