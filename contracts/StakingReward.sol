// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IStakingReward.sol";
import "./RewardsDistributionRecipient.sol";

contract StakingRewards is
  IStakingRewards,
  RewardsDistributionRecipient,
  ReentrancyGuard,
  Pausable
{
  using SafeERC20 for IERC20;

  /* ========== STATE VARIABLES ========== */

  IERC20 public rewardsToken;
  IERC20 public stakingToken;
  uint256 public periodFinish = 0;
  uint256 public rewardRate = 0;
  uint256 public rewardsDuration = 7 days;
  uint256 public lastUpdateTime;
  uint256 public rewardPerTokenStored;

  mapping(address => uint256) public userRewardPerTokenPaid;
  mapping(address => uint256) public rewards;

  uint256 private _totalSupply;
  mapping(address => uint256) private _balances;

  /* ========== CONSTRUCTOR ========== */

  constructor(
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken
  ) {
    rewardsToken = IERC20(_rewardsToken);
    stakingToken = IERC20(_stakingToken);
    rewardsDistribution = _rewardsDistribution;
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  function stake(uint256 amount)
    external
    override
    nonReentrant
    whenNotPaused
    updateReward(msg.sender)
  {
    require(amount > 0, "Cannot stake 0");
    _totalSupply = _totalSupply + amount;
    _balances[msg.sender] = _balances[msg.sender] + amount;
    stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    emit Staked(msg.sender, amount);
  }

  function exit() external override {
    withdraw(_balances[msg.sender]);
    getReward();
  }

  function withdraw(uint256 amount)
    public
    override
    nonReentrant
    updateReward(msg.sender)
  {
    require(amount > 0, "Cannot withdraw 0");
    require(_balances[msg.sender] >= amount, "exceeding staked amount");
    _totalSupply = _totalSupply - amount;
    _balances[msg.sender] = _balances[msg.sender] - amount;
    stakingToken.safeTransfer(msg.sender, amount);
    emit Withdrawn(msg.sender, amount);
  }

  function getReward() public override nonReentrant updateReward(msg.sender) {
    uint256 reward = rewards[msg.sender];
    if (reward > 0) {
      rewards[msg.sender] = 0;
      rewardsToken.safeTransfer(msg.sender, reward);
      emit RewardPaid(msg.sender, reward);
    }
  }

  /* ========== RESTRICTED FUNCTIONS ========== */

  function notifyRewardAmount(uint256 reward)
    external
    override
    onlyRewardsDistribution
    updateReward(address(0))
  {
    if (block.timestamp >= periodFinish) {
      rewardRate = reward / rewardsDuration;
    } else {
      uint256 remaining = periodFinish - block.timestamp;
      uint256 leftover = remaining * rewardRate;
      rewardRate = reward + leftover / rewardsDuration;
    }

    IERC20(rewardsToken).safeTransferFrom(msg.sender, address(this), reward);

    lastUpdateTime = block.timestamp;
    periodFinish = block.timestamp + rewardsDuration;
    emit RewardAdded(reward);
  }

  function recoverERC20(address tokenAddress, uint256 tokenAmount)
    external
    onlyOwner
  {
    require(
      tokenAddress != address(stakingToken) &&
        tokenAddress != address(rewardsToken),
      "no reward or staking token"
    );
    IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    emit Recovered(tokenAddress, tokenAmount);
  }

  function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
    require(block.timestamp > periodFinish, "period not finished");
    rewardsDuration = _rewardsDuration;
    emit RewardsDurationUpdated(rewardsDuration);
  }

  /* ========== VIEWS ========== */

  function totalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) external view override returns (uint256) {
    return _balances[account];
  }

  function getRewardForDuration() external view override returns (uint256) {
    return rewardRate * rewardsDuration;
  }

  function lastTimeRewardApplicable() public view override returns (uint256) {
    return block.timestamp < periodFinish ? block.timestamp : periodFinish;
  }

  function rewardPerToken() public view override returns (uint256) {
    if (_totalSupply == 0) {
      return rewardPerTokenStored;
    }
    return
      rewardPerTokenStored +
      (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * (1e18)) /
        _totalSupply);
  }

  function earned(address account) public view override returns (uint256) {
    return
      (_balances[account] *
        (rewardPerToken() - (userRewardPerTokenPaid[account]))) /
      (1e18) +
      (rewards[account]);
  }

  /* ========== MODIFIERS ========== */

  modifier updateReward(address account) {
    rewardPerTokenStored = rewardPerToken();

    lastUpdateTime = lastTimeRewardApplicable();
    if (account != address(0)) {
      rewards[account] = earned(account);
      userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
    _;
  }

  /* ========== EVENTS ========== */

  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, uint256 reward);
  event RewardsDurationUpdated(uint256 newDuration);
  event Recovered(address token, uint256 amount);
}
