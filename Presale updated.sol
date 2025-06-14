// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IUSDT {
    function transfer(address to, uint256 value) external;
    function transferFrom(address from, address to, uint256 value) external;
    function approve(address spender, uint256 value) external;
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

interface IUniswapPair {
    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    );
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract RICPresale is Ownable(msg.sender), ReentrancyGuard {
    using SafeMath for uint256;

    // Presale Token
    IERC20 public ricToken;
    uint256 public presaleStartTime;
    uint256 public presaleEndTime;
    uint256 public totalTokensForSale;
    uint256 public holders;
    uint256 public tokensSold;
    uint256 public tokensSoldPrevious;
    uint256 public minContribution;
    uint256 public maxContribution;
    uint256 public totalBonus;
    uint256 public totalEarnedUSD;
    uint256 public ricPriceUSD = 50 * 10**18; // $100 per RIC    Token price in USD (18 decimals)
    uint256 public tokensForDev = 200 * 10**18; // tokens to developer
    uint256 public stage = 1;
    bool public presaleFinalized;

    uint256 public ethPriceUSD;
    uint256 public btcPriceUSD;
    address public uniswapPairETH;
    address public uniswapPairBTC;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant ETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant BTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    //address of developer
    address public dev1 = 0x6239d067cAf2C5D648FDaeAE31155eEaB319B8F5;
    address public dev2 = 0xbC439D9f2BB93c397b7bCA598d45DA39D09D9B82;

    // Track contributions
    struct Contribution {
        uint256 totalUSD;
        uint256 usdtAmount;
        uint256 usdcAmount;
        uint256 ethAmount;
        uint256 btcAmount;
    }
    mapping(address => Contribution) public contributions;
    mapping(address => uint256) public tokensClaimed;
    mapping(address => address) public referrers;
    mapping(address => bool) public hasDeposit;

    // Events
    event TokensPurchased(address indexed buyer, address indexed paymentToken, uint256 amountPaid, uint256 tokensReceived);
    event PresaleExtended(uint256 newEndTime);
    event PresaleFinalized(uint256 tokensRemaining);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    event PriceUpdated(uint256 ricPriceUSD);
    event ETHPricesUpdated(uint256 ethPrice, uint256 btcPrice);

    constructor(
        address _ricToken,
        uint256 _presaleStartTime,
        uint256 _presaleDuration,
        uint256 _totalTokensForSale,
        uint256 _minContribution,
        uint256 _maxContribution,
        address _uniswapPairETH,
        address _uniswapPairBTC
    ) {
        require(_ricToken != address(0), "RIC token address cannot be zero");
        require(_presaleStartTime > block.timestamp, "Start time must be in future");
        require(_presaleDuration > 0, "Duration must be positive");
        require(_totalTokensForSale > 0, "Tokens for sale must be positive");

        ricToken = IERC20(_ricToken);
        presaleStartTime = _presaleStartTime;
        presaleEndTime = _presaleStartTime.add(_presaleDuration);
        totalTokensForSale = _totalTokensForSale;
        minContribution = _minContribution;
        maxContribution = _maxContribution;
        uniswapPairETH = _uniswapPairETH;
        uniswapPairBTC = _uniswapPairBTC;
    }

    // Update Stage
    function updateStage(uint256 _stage) external onlyOwner {
        require(_stage > 0, "Stage must be positive");
        stage = _stage;
    }

    function updateAllPricesFromLP() public {
         // ETH/DAI
        if (uniswapPairETH != address(0)) {
            (uint112 reserve0, uint112 reserve1, ) = IUniswapPair(uniswapPairETH).getReserves();
            address token0 = IUniswapPair(uniswapPairETH).token0();
            if (token0 == ETH) {
                ethPriceUSD = uint256(reserve1) * 1e18 / uint256(reserve0);
            } else {
                ethPriceUSD = uint256(reserve0) * 1e18 / uint256(reserve1);
            }
        }
        // BTC/DAI
        if (uniswapPairBTC != address(0)) {
            (uint112 reserve0, uint112 reserve1, ) = IUniswapPair(uniswapPairBTC).getReserves();
            address token0 = IUniswapPair(uniswapPairBTC).token0();
            if (token0 == BTC) {
                btcPriceUSD = uint256(reserve1) * 1e8 / uint256(reserve0);
            } else {
                btcPriceUSD = uint256(reserve0) * 1e8 / uint256(reserve1);
            }
        }
        emit ETHPricesUpdated(ethPriceUSD, btcPriceUSD);
    }

    function updatePairs(address _uniswapPairETH, address _uniswapPairBTC) external onlyOwner {
        require(_uniswapPairETH != address(0), "address cannot be zero");
        require(_uniswapPairBTC != address(0), "address cannot be zero");
        uniswapPairETH = _uniswapPairETH;
        uniswapPairBTC = _uniswapPairBTC;
    }

    // Update RIC Token price
    function updatePrice(uint256 _ricPriceUSD) external onlyOwner {
        require(_ricPriceUSD > 0, "Prices must be positive");
        ricPriceUSD = _ricPriceUSD;
        emit PriceUpdated(_ricPriceUSD);
    }

    // Update ETH prices
    function updateETHPrices(
        uint256 _ethPrice,
        uint256 _btcPrice
    ) external onlyOwner {
        require(_ethPrice > 0 && _btcPrice > 0, "Prices must be positive");
        ethPriceUSD = _ethPrice;
        btcPriceUSD = _btcPrice;
        emit ETHPricesUpdated(_ethPrice, _btcPrice);
    }

    //change the address of developer
    function updateDev1(address _newDev) external {
        require(msg.sender == dev1, "Not allowed");
        require(_newDev != address(0), "Not set new developer");
        dev1 = _newDev;
    }

    function updateContribution(uint256 _min, uint256 _max) external onlyOwner{
        minContribution = _min;
        maxContribution = _max;
    }

    //change the address of developer 2
    function updateDev2(address _newDev) external {
        require(msg.sender == dev2, "Not allowed");
        require(_newDev != address(0), "Not set second developer");
        dev2 = _newDev;
    }

    function tokenTransfer(address token, address to, uint256 amount) internal {
        require(to != address(0), "Cannot transfer to zero address");
        if(token == USDT) {
            IUSDT(token).transfer(to, amount);
        } else {
            IERC20(token).transfer(to, amount);
        }
    }

    // Contribute with ETH
    function contributeETH(address adr_referrer) external payable nonReentrant {
        require(block.timestamp >= presaleStartTime, "Presale has not started");
        require(block.timestamp <= presaleEndTime, "Presale has ended");
        require(msg.value > 0, "Contribution must be positive");
        require(ethPriceUSD > 0, "ETH price not set");

        updateAllPricesFromLP();

        uint256 usdValue = msg.value.mul(ethPriceUSD).div(10**18);
        contributions[msg.sender].totalUSD = contributions[msg.sender].totalUSD.add(usdValue);
        contributions[msg.sender].ethAmount = contributions[msg.sender].ethAmount.add(msg.value);
        //reward to referrer
        uint256 prev_balance = address(this).balance; //before referrer balance
        if (referrers[msg.sender] == address(0) && adr_referrer != msg.sender && adr_referrer != address(0)) {
            referrers[msg.sender] = adr_referrer;
        }
         // 3-level referral rewards
        address ref1 = referrers[msg.sender];
        address ref2 = ref1 != address(0) ? referrers[ref1] : address(0);
        address ref3 = ref2 != address(0) ? referrers[ref2] : address(0);

        // Level 1: 6%
        if(ref1 != address(0) && ref1 != msg.sender){
            uint256 reward1 = msg.value.mul(6).div(100);
            payable(ref1).transfer(reward1);
        }
        // Level 2: 2%
        if(ref2 != address(0) && ref2 != msg.sender){
            uint256 reward2 = msg.value.mul(2).div(100);
            payable(ref2).transfer(reward2);
        }
        // Level 3: 1%
        if(ref3 != address(0) && ref3 != msg.sender){
            uint256 reward3 = msg.value.mul(1).div(100);
            payable(ref3).transfer(reward3);
        }

        _processContribution(ETH, msg.value, usdValue);

        uint256 after_balance = address(this).balance;
        uint256 differ_balance = prev_balance.sub(after_balance);

        if(tokensSold <= tokensForDev){
            payable(dev1).transfer(after_balance);
        }
        else if(tokensSold > tokensForDev){
            if(tokensSoldPrevious <=tokensForDev){
                uint256 amount_to_developer_temp = tokensForDev.sub(tokensSoldPrevious);
                uint256 differ_sold = tokensSold.sub(tokensSoldPrevious);
                uint256 amount_to_developer = (msg.value.sub(differ_balance)).mul(amount_to_developer_temp).div(differ_sold);
                uint256 amount_to_developer_owner = msg.value.sub(differ_balance).sub(amount_to_developer);
                payable(dev1).transfer(amount_to_developer);
                payable(dev1).transfer(amount_to_developer_owner.div(100));
                payable(dev2).transfer(amount_to_developer_owner.div(100));
            }
            payable(dev1).transfer((msg.value.sub(differ_balance)).div(100));
            payable(dev2).transfer((msg.value.sub(differ_balance)).div(100));
        }
    }

    // Contribute with ERC20 tokens
    function contributeERC20(address token, uint256 amount, address adr_referrer) external nonReentrant {
        require(block.timestamp >= presaleStartTime, "Presale has not started");
        require(block.timestamp <= presaleEndTime, "Presale has ended");
        require(amount > 0, "Contribution must be positive");
        require(token == USDT || token == USDC || token == BTC, "Unsupported token");

        if(token == USDT) {
            IUSDT(token).transferFrom(msg.sender, address(this), amount);
        } else {
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        }

        updateAllPricesFromLP();
        uint256 usdValue;
        if (token == USDT || token == USDC) {
            usdValue = amount.mul(10**12); // USDT/USDC have 6 decimals
            if (token == USDT) {
                contributions[msg.sender].usdtAmount = contributions[msg.sender].usdtAmount.add(amount);
            } else {
                contributions[msg.sender].usdcAmount = contributions[msg.sender].usdcAmount.add(amount);
            }}
        else if (token == BTC) {
            require(btcPriceUSD > 0, "BTC price not set");
            usdValue = amount.mul(btcPriceUSD).div(10**8);
            contributions[msg.sender].btcAmount = contributions[msg.sender].btcAmount.add(amount);
        }
        contributions[msg.sender].totalUSD = contributions[msg.sender].totalUSD.add(usdValue);        

        //reward to referrer
        uint256 prev_balance = address(this).balance; //before referrer balance
        if (referrers[msg.sender] == address(0) && adr_referrer != msg.sender && adr_referrer != address(0)) {
            referrers[msg.sender] = adr_referrer;
        }
         // 3-level referral rewards
        address ref1 = referrers[msg.sender];
        address ref2 = ref1 != address(0) ? referrers[ref1] : address(0);
        address ref3 = ref2 != address(0) ? referrers[ref2] : address(0);

        // Level 1: 6%
        if(ref1 != address(0) && ref1 != msg.sender){
            uint256 reward1 = amount.mul(6).div(100);
            tokenTransfer(token, ref1, reward1);
        }
        // Level 2: 2%
        if(ref2 != address(0) && ref2 != msg.sender){
            uint256 reward2 = amount.mul(2).div(100);
            tokenTransfer(token, ref2, reward2);
        }
        // Level 3: 1%
        if(ref3 != address(0) && ref3 != msg.sender){
            uint256 reward3 = amount.mul(1).div(100);
            tokenTransfer(token, ref3, reward3);
        }

        _processContribution(token, amount, usdValue);

        uint256 after_balance = address(this).balance;
        uint256 differ_balance = prev_balance.sub(after_balance);

        //inserted by Po
        if(tokensSold <= tokensForDev){  
            tokenTransfer(token, dev1, after_balance);
        }
        else if(tokensSold > tokensForDev){
            if (tokensSoldPrevious <= tokensForDev) {
                uint256 amountToDevTemp = tokensForDev.sub(tokensSoldPrevious);
                uint256 differSold = tokensSold.sub(tokensSoldPrevious);
                uint256 adjustedAmount = amount.sub(differ_balance);
                uint256 amountToDev = adjustedAmount.mul(amountToDevTemp).div(differSold);
                uint256 amountToOwner = adjustedAmount.sub(amountToDev);
                tokenTransfer(token, dev1, amountToDev);
                tokenTransfer(token, dev1, amountToOwner.div(100));
                tokenTransfer(token, dev2, amountToOwner.div(100));
            } 
                tokenTransfer(token, dev1, (amount.sub(differ_balance)).div(100));
                tokenTransfer(token, dev2, (amount.sub(differ_balance)).div(100));
            
        }
    }

    function _processContribution(address paymentToken, uint256 amountPaid, uint256 usdValue) private {
        require(usdValue >= minContribution, "Contribution below minimum");
        require(contributions[msg.sender].totalUSD <= maxContribution, "Contribution exceeds maximum");

        if(!hasDeposit[msg.sender]){
            holders += 1;
            hasDeposit[msg.sender] = true;
        }
        uint256 tokensToReceive = usdValue.mul(10**18).div(ricPriceUSD);

        //give Bonus section
        uint256 bonusInNow;
        if(totalBonus <= 40000 * 10 ** 18){
            if(tokensToReceive  >= 10 ** 19 && tokensToReceive  < 10  ** 20){
                bonusInNow = tokensToReceive.mul(5).div(100);
            }
            else if(tokensToReceive  >= 10 ** 20 && tokensToReceive  < 10  ** 21){
                bonusInNow = tokensToReceive.mul(10).div(100);
            }
            else if(tokensToReceive  >= 10 ** 21){
                bonusInNow = tokensToReceive.mul(12).div(100);
            }
            tokensToReceive = tokensToReceive.add(bonusInNow);
            totalBonus = totalBonus.add(bonusInNow);
        }
        
        require(ricToken.balanceOf(address(this)) >= tokensToReceive, "tokens to receive exceeds");
        require(tokensSold.add(tokensToReceive) <= totalTokensForSale, "Not enough tokens remaining");

        tokensSold = tokensSold.add(tokensToReceive);
        tokensSoldPrevious = tokensSold.sub(tokensToReceive); // Store previous tokens sold for stage logic

        if (500000*10**18 < tokensSold && tokensSold<= 2500000*10**18) {
            stage = 2;
            ricPriceUSD = 75 * 10 ** 18;
        }
        if (2500000 *10**18< tokensSold) {
            ricPriceUSD = 100 * 10 ** 18;
        }
        
        // Immediately transfer tokens (or could be vested)
        require(ricToken.transfer(msg.sender, tokensToReceive), "Token transfer failed");
        getTotalEarnedUSD();

        emit TokensPurchased(msg.sender, paymentToken, amountPaid, tokensToReceive);
    }

    // Admin functions
    function extendPresale(uint256 additionalTime) external onlyOwner {
        // require(block.timestamp < presaleEndTime, "Presale already ended");
        presaleEndTime = presaleEndTime.add(additionalTime);
        emit PresaleExtended(presaleEndTime);
    }

    function finalizePresale() external onlyOwner {
        require(block.timestamp > presaleEndTime, "Presale not ended");
        require(!presaleFinalized, "Presale already finalized");

        presaleFinalized = true;
        uint256 remainingTokens = ricToken.balanceOf(address(this));

        if (remainingTokens > 0) {
            // Return unsold tokens to owner
            require(ricToken.transfer(owner(), remainingTokens), "Token transfer failed");
        }
        emit PresaleFinalized(remainingTokens);
    }

    function withdrawFunds(address token) external onlyOwner {
        require(presaleFinalized, "Presale not finalized");

        if (token == ETH) {
            payable(owner()).transfer(address(this).balance);
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            tokenTransfer(token, owner(), balance);
        }
        emit FundsWithdrawn(owner(), token == ETH ? address(this).balance : IERC20(token).balanceOf(address(this)));
    }

    // Emergency stop
    function emergencyStop() external onlyOwner {
        presaleEndTime = block.timestamp;
    }

    // Get token amount for USD value
    function getTokenAmount(uint256 usdAmount) public view returns (uint256) {
        return usdAmount.mul(10**18).div(ricPriceUSD);
    }

    // Get contribution in USD
    function getContributionUSD(address contributor) public view returns (uint256) {
        return contributions[contributor].totalUSD;
    }

    //get total USD in presale
    function getTotalEarnedUSD() public returns (uint256){
        uint256 tokensSold_temp = tokensSold.div(10 ** 18);
        if(tokensSold_temp <= 500000){
            totalEarnedUSD = tokensSold_temp * 50;
        }
        else if(tokensSold_temp <=2500000 && tokensSold_temp > 500000){
            totalEarnedUSD = (tokensSold_temp.sub(500000)).mul(75).add(500000 * 50);
        }
        else if(tokensSold_temp > 2500000){
            totalEarnedUSD = (tokensSold_temp - 2500000) * 100 + 75 * 2000000 + 50 * 500000;
        }
        return totalEarnedUSD;
    }
}