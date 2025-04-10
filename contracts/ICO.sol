// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 

contract ChainSphereTokenICO is ERC20, ERC20Burnable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- New Token Variables for multi-standard USDT ---
    IERC20 public usdtERC20;
    IERC20 public usdtBEP20;
    
    // (Optional fallback variable if needed, but not used in buyToken)
    // IERC20 public usdt;

    uint256 public icoStart;
    uint256 public icoEnd;
    bool public manualPause;
    uint256 public soldTokens;
    uint256 public tokenPrice;

    // vesting part
    uint256 public lockDuration = 2 minutes;
    uint256 public vestingInterval = 1 minutes;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 lockEndTime;
        uint256 unlockPerBatch;
    }
    mapping(address => VestingSchedule) public vestingSchedules;

    struct SalePhaseInfo {
        uint256 allocatedSupply;
        uint256 price;
        uint256 lockingPeriod;
    }

    enum SalePhase {
        notStarted,
        Privatesale,
        Presale1,
        Presale2,
        Publicsale,
        Pause,
        Ended
    }
    SalePhase public salePhase;
    mapping(SalePhase => SalePhaseInfo) public salePhases;

    struct LockingSchedule {
        uint256 amount;
        uint256 purchaseTime;
        SalePhase phase;
        uint256 unlockTime;
    }
    mapping(address => LockingSchedule[]) public lockingBalances;
    mapping(SalePhase => address[]) public phaseBuyers;

    event TokenBought(
        address indexed buyer,
        uint256 usdtAmount,
        uint256 tokenAmount,
        uint256 unlockTime
    );
    event TokensClaimed(address indexed buyer, uint256 amount);

    struct UserSaleDetails{
        uint256 saleType;
        uint256 totalTokens;
    }
    mapping(address => UserSaleDetails) public userDetails;
    
    // --- New Enum to select token standard ---
    enum TokenStandard { ERC20, BEP20 }

    // --- Updated Constructor ---
    // Now takes two addresses: one for the official USDT ERC20 and one for the official USDT BEP20.
    constructor(address _usdtERC20, address _usdtBEP20)
        ERC20("ChainSphereToken", "CSP")
        Ownable(msg.sender)
    {
        require(_usdtERC20 != address(0) && _usdtBEP20 != address(0), "Invalid USDT addresses");
        usdtERC20 = IERC20(_usdtERC20);
        usdtBEP20 = IERC20(_usdtBEP20);
        // Optionally, you could set the fallback usdt variable to one of these:
        // usdt = IERC20(_usdtERC20);

        uint256 totalSupply = 5310000000 * 10**decimals();
        _mint(msg.sender, totalSupply);

        salePhases[SalePhase.Privatesale] = SalePhaseInfo(
            (totalSupply * 10) / 100,
            5 * 10**16,
            730 days
        );
        salePhases[SalePhase.Presale1] = SalePhaseInfo(
            (totalSupply * 10) / 100,
            7 * 10**16,
            730 days
        );
        salePhases[SalePhase.Presale2] = SalePhaseInfo(
            (totalSupply * 10) / 100,
            9 * 10**16,
            730 days
        );
        salePhases[SalePhase.Publicsale] = SalePhaseInfo(
            (totalSupply * 5) / 100,
            12 * 10**16,
            730 days
        ); // No lock

        salePhase = SalePhase.notStarted;
    }

    // --- New Setter Functions for USDT addresses ---
    function setERC20USDT(address _usdtERC20) external onlyOwner {
        require(_usdtERC20 != address(0), "Invalid address");
        usdtERC20 = IERC20(_usdtERC20);
    }
    
    function setBEP20USDT(address _usdtBEP20) external onlyOwner {
        require(_usdtBEP20 != address(0), "Invalid address");
        usdtBEP20 = IERC20(_usdtBEP20);
    }

    modifier onlyDuringICO() {
        require(
            block.timestamp >= icoStart && block.timestamp <= icoEnd,
            "ICO is not active"
        );
        _;
    }

    function setStartTime(uint256 startTime_) external onlyOwner {
        require(
            startTime_ > block.timestamp,
            "Start time must be in the future"
        );
        icoStart = startTime_;
    }

    function setEndTime(uint256 endTime_) external onlyOwner {
        require(endTime_ > icoStart, "End time must be after start time");
        icoEnd = endTime_;
    }

    function PauseResume() external onlyOwner {
        manualPause = !manualPause;
        if (manualPause) {
            salePhase = SalePhase.Pause;
        }
    }

    function setLockingPeriod(SalePhase phase, uint256 period)
        external
        onlyOwner
    {
        require(salePhases[phase].allocatedSupply > 0, "Invalid sale phase");
        salePhases[phase].lockingPeriod = period;

        address[] storage buyers = phaseBuyers[phase];
        for (uint256 i = 0; i < buyers.length; i++) {
            LockingSchedule[] storage schedules = lockingBalances[buyers[i]];
            for (uint256 j = 0; j < schedules.length; j++) {
                if (schedules[j].amount > 0 && schedules[j].phase == phase) {
                    schedules[j].unlockTime =
                        schedules[j].purchaseTime +
                        period;
                }
            }
        }
    }

    function setSalePhase(SalePhase phase) external onlyOwner {
        require(!manualPause, "Cannot change phase while ICO is paused");
        require(
            (phase == SalePhase.Privatesale &&
                salePhase == SalePhase.notStarted) ||
                (phase == SalePhase.Presale1 &&
                    salePhase == SalePhase.Privatesale) ||
                (phase == SalePhase.Presale2 &&
                    salePhase == SalePhase.Presale1) ||
                (phase == SalePhase.Publicsale &&
                    salePhase == SalePhase.Presale2) ||
                (phase == SalePhase.Ended && salePhase == SalePhase.Publicsale),
            "Invalid sale phase transition!"
        );
        salePhase = phase;
        tokenPrice = salePhases[phase].price;
    }

    // --- Updated buyToken Function ---
    // Added an extra parameter "tokenStandard" to indicate which USDT (ERC20/BEP20) to use
    function buyToken(
    uint256 usdtAmount,
    uint256 bnbPrice_,
    TokenStandard tokenStandard
) external payable onlyDuringICO nonReentrant {
    require(
        salePhase != SalePhase.notStarted &&
        salePhase != SalePhase.Pause &&
        salePhase != SalePhase.Ended,
        "No active sale phase"
    );
 
    SalePhaseInfo storage currentPhase = salePhases[salePhase];
    uint256 tokenAmount;
    uint256 currentTime = block.timestamp;
    uint256 unlockTime = currentTime + currentPhase.lockingPeriod;
 
    // Handle payment method
    if (msg.value > 0) {
        // --- BNB Payment ---
        require(usdtAmount == 0, "Cannot send both BNB and USDT");
        require(bnbPrice_ > 0, "Invalid BNB price");
        tokenAmount = (msg.value * 10**18) / bnbPrice_;
    } else {
        // --- USDT Payment ---
        require(usdtAmount > 0, "USDT amount must be > 0");
 
        tokenAmount = (usdtAmount * 10**18) / currentPhase.price;
 
        if (tokenStandard == TokenStandard.ERC20) {
            require(address(usdtERC20) != address(0), "ERC20 USDT not set");
            usdtERC20.safeTransferFrom(msg.sender, address(this), usdtAmount);
        } else if (tokenStandard == TokenStandard.BEP20) {
            require(address(usdtBEP20) != address(0), "BEP20 USDT not set");
            usdtBEP20.safeTransferFrom(msg.sender, address(this), usdtAmount);
        } else {
            revert("Unsupported token standard");
        }
    }
 
    require(tokenAmount > 0, "Token amount must be > 0");
    require(currentPhase.allocatedSupply >= tokenAmount, "Insufficient allocated tokens");
    require(balanceOf(owner()) >= tokenAmount, "Not enough tokens in owner's balance");
 
    // Locking & tracking
    lockingBalances[msg.sender].push(
        LockingSchedule({
            amount: tokenAmount,
            purchaseTime: currentTime,
            phase: salePhase,
            unlockTime: unlockTime
        })
    );
 
    phaseBuyers[salePhase].push(msg.sender);
    soldTokens += tokenAmount;
    currentPhase.allocatedSupply -= tokenAmount;
 
    _transfer(owner(), msg.sender, tokenAmount);
 
    userDetails[msg.sender].saleType = uint256(salePhase);
    userDetails[msg.sender].totalTokens += tokenAmount;
 
    emit TokenBought(
        msg.sender,
        usdtAmount > 0 ? usdtAmount : msg.value,
        tokenAmount,
        unlockTime
    );
}

    function claimTokens() external nonReentrant {
        LockingSchedule[] storage schedules = lockingBalances[msg.sender];
        uint256 totalClaimable = 0;
        for (uint256 i = 0; i < schedules.length; i++) {
            if (
                schedules[i].amount > 0 &&
                block.timestamp >= schedules[i].unlockTime
            ) {
                totalClaimable += schedules[i].amount;
                schedules[i].amount = 0; // Mark as claimed/unlocked
            }
        }
        require(totalClaimable > 0, "No unlocked tokens to claim");
        emit TokensClaimed(msg.sender, totalClaimable);
    }

    function availableBalance(address account) public view returns (uint256) {
        uint256 locked = 0;
        LockingSchedule[] memory schedules = lockingBalances[account];
        for (uint256 i = 0; i < schedules.length; i++) {
            if (
                schedules[i].amount > 0
            ) {
                locked += schedules[i].amount;
            }
        }
        return balanceOf(account) - locked;
    }

    function checkStatus() external view returns (string memory) {
        if (manualPause) return "ICO is manually paused by owner";
        if (icoStart == 0 || icoEnd == 0) return "ICO has not started yet";
        if (block.timestamp >= icoStart && block.timestamp <= icoEnd)
            return "ICO is active";
        if (block.timestamp > icoEnd) return "ICO has ended";
        return "ICO has not started yet";
    }

    // Override transfer to ensure locked tokens cannot be transferred.
    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        require(
            availableBalance(msg.sender) >= amount,
            "Insufficient unlocked balance because you have not claimed yet"
        );
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            availableBalance(sender) >= amount,
            "You tokens are still locked or you haven't claimed yet"
        );
        return super.transferFrom(sender, recipient, amount);
    }

    function transferWithLock(address recipient, uint256 amount)
        external
        onlyOwner
    {
        require(balanceOf(owner()) >= amount, "Not enough tokens");
        _transfer(owner(), address(this), amount);

        vestingSchedules[recipient] = VestingSchedule({
            totalAmount: amount,
            claimedAmount: 0,
            lockEndTime: block.timestamp + lockDuration,
            unlockPerBatch: (amount * 20) / 100
        });
    }

    function claimVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No tokens allocated for vesting");
        require(
            block.timestamp >= schedule.lockEndTime,
            "Lock period is still active"
        );

        uint256 unlocked = getUnlockedTokens(msg.sender);
        require(unlocked > 0, "No vested tokens available to claim");

        schedule.claimedAmount += unlocked;
        _transfer(address(this), msg.sender, unlocked);
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 unlockedBalance = super.balanceOf(account);
        // If there is a vesting schedule, include the locked tokens.
        VestingSchedule storage schedule = vestingSchedules[account];
        uint256 lockedTokens = 0;
        if (schedule.totalAmount > 0) {
            lockedTokens = schedule.totalAmount - schedule.claimedAmount;
        }
        return unlockedBalance + lockedTokens;
    }

    function getLockedTokens(address user) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[user];
        if (block.timestamp < schedule.lockEndTime) {
            return schedule.totalAmount;
        }
        
        // Calculate total intervals that have passed since lock end.
        uint256 intervalsPassed = (block.timestamp - schedule.lockEndTime) / vestingInterval;
        uint256 totalUnlocked = intervalsPassed * schedule.unlockPerBatch;
        if (totalUnlocked > schedule.totalAmount) {
            totalUnlocked = schedule.totalAmount;
        }
        return schedule.totalAmount - totalUnlocked;
    }

    function getUnlockedTokens(address user) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[user];

        if (block.timestamp < schedule.lockEndTime) {
            return 0;
        }

        uint256 intervalsPassed = (block.timestamp - schedule.lockEndTime) /
            vestingInterval;
        uint256 totalUnlocked = intervalsPassed * schedule.unlockPerBatch;

        if (totalUnlocked > schedule.totalAmount) {
            totalUnlocked = schedule.totalAmount;
        }

        return totalUnlocked - schedule.claimedAmount;
    }

    function getUSDTbalance() public view onlyOwner returns(uint256) {
        // For convenience, you might return the ERC20 token balance; you could add BEP20 too if needed.
        return usdtERC20.balanceOf(address(this));
    }

    function getBNBbalance() public view onlyOwner returns(uint256) {
        return address(this).balance;
    }

    function Withdraw() external onlyOwner {
        uint256 amount = usdtERC20.balanceOf(address(this));
        require(amount > 0, "No usdt to withdraw");
        require(usdtERC20.transfer(owner(), amount), "withdraw failed");
    }

    function withdrawBNB() external onlyOwner {
       uint256 balance = address(this).balance;
       require(balance > 0, "No BNB available in contract");
       payable(owner()).transfer(balance);
    }
  
    // this function is callable by backend
    function TransferRewards(address recipient_, uint256 amount_, uint256 lockTime_) public onlyOwner {
        require(recipient_ != address(0), "recipient address is not valid");
        require(amount_ > 0, "amount should be > 0");
        require(lockTime_ > 0, "lock time should in future");
        require(balanceOf(owner()) >= amount_, "owner doesn't have enough tokens");
        
        _transfer(msg.sender, recipient_, amount_);
       
       lockingBalances[recipient_].push (LockingSchedule({
           amount: amount_,
           purchaseTime: block.timestamp,
           phase: SalePhase.Ended,
           unlockTime: block.timestamp + lockTime_
         })
       );
    }
}
