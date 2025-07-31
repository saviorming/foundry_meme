// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./MemeToken.sol";

/**
 * @title MemeFactory
 * @dev Meme代币工厂合约
 * @notice 使用最小代理模式高效部署Meme代币，并处理铸造和费用分配
 * @author Meme Launch Platform Team
 */
contract MemeFactory is Ownable, ReentrancyGuard {
    using Clones for address;
    
    // MemeToken实现合约地址
    address public immutable memeTokenImplementation;
    
    // 项目钱包地址（用于接收平台费用）
    address public projectWallet;
    
    // 平台费用比例（基点，1% = 100）
    uint256 public constant PROJECT_FEE_BPS = 100; // 1%
    uint256 public constant BASIS_POINTS = 10000; // 100%
    
    // 代币地址到代币信息的映射
    mapping(address => TokenInfo) public tokenInfo;
    
    // 所有已部署代币的数组
    address[] public deployedTokens;
    
    /**
     * @dev 代币信息结构体
     * @param symbol 代币符号
     * @param totalSupply 总供应量
     * @param perMint 每次铸造数量
     * @param price 每个代币单位的价格（wei）
     * @param creator 创建者地址
     * @param exists 代币是否存在的标志
     */
    struct TokenInfo {
        string symbol;
        uint256 totalSupply;
        uint256 perMint;
        uint256 price;
        address creator;
        bool exists;
    }
    
    /**
     * @dev Meme代币部署事件
     * @param tokenAddress 部署的代币合约地址
     * @param creator 创建者地址
     * @param symbol 代币符号
     * @param totalSupply 总供应量
     * @param perMint 每次铸造数量
     * @param price 每个代币单位的价格
     */
    event MemeDeployed(
        address indexed tokenAddress,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    
    /**
     * @dev Meme代币铸造事件
     * @param tokenAddress 代币合约地址
     * @param minter 铸造者地址
     * @param amount 铸造数量
     * @param totalPaid 总支付金额
     * @param projectFee 平台费用
     * @param creatorFee 创建者费用
     */
    event MemeMinted(
        address indexed tokenAddress,
        address indexed minter,
        uint256 amount,
        uint256 totalPaid,
        uint256 projectFee,
        uint256 creatorFee
    );
    
    /**
     * @dev 构造函数
     * @param _projectWallet 项目钱包地址，用于接收平台费用
     * @notice 部署MemeToken实现合约并设置项目钱包
     */
    constructor(address _projectWallet) Ownable(msg.sender) {
        require(_projectWallet != address(0), "Project wallet cannot be zero address");
        
        projectWallet = _projectWallet;
        
        // 部署实现合约
        memeTokenImplementation = address(new MemeToken());
    }
    
    /**
     * @dev 部署新的Meme代币
     * @param symbol 代币符号
     * @param totalSupply 代币总供应量
     * @param perMint 每次铸造的数量
     * @param price 每个代币单位的价格（wei）
     * @return 部署的代币合约地址
     * @notice 使用最小代理模式克隆实现合约，节省gas费用
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        require(perMint <= totalSupply, "Per mint cannot exceed total supply");
        
        // 克隆实现合约
        address tokenClone = memeTokenImplementation.clone();
        
        // 初始化克隆的合约
        MemeToken(tokenClone).initialize(
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender,
            address(this)
        );
        
        // 存储代币信息
        tokenInfo[tokenClone] = TokenInfo({
            symbol: symbol,
            totalSupply: totalSupply,
            perMint: perMint,
            price: price,
            creator: msg.sender,
            exists: true
        });
        
        deployedTokens.push(tokenClone);
        
        emit MemeDeployed(tokenClone, msg.sender, symbol, totalSupply, perMint, price);
        
        return tokenClone;
    }
    
    /**
     * @dev 铸造Meme代币（需要支付费用）
     * @param tokenAddr 要铸造的Meme代币合约地址
     * @notice 用户需要支付足够的ETH来铸造代币，费用会分配给平台和创建者
     * @notice 使用重入保护确保安全性
     */
    function mintMeme(address tokenAddr) external payable nonReentrant {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        
        MemeToken token = MemeToken(tokenAddr);
        TokenInfo memory info = tokenInfo[tokenAddr];
        
        require(token.remainingSupply() >= info.perMint, "Cannot mint more tokens");
        
        // 计算总费用
        uint256 totalCost = info.perMint * info.price;
        require(msg.value >= totalCost, "Insufficient payment");
        
        // 计算费用分配
        uint256 projectFee = (totalCost * PROJECT_FEE_BPS) / BASIS_POINTS;
        uint256 creatorFee = totalCost - projectFee;
        
        // 向购买者铸造代币
        token.mint(msg.sender, info.perMint);
        
        // 转移平台费用
        if (projectFee > 0) {
            (bool projectSuccess, ) = projectWallet.call{value: projectFee}("");
            require(projectSuccess, "Project fee transfer failed");
        }
        
        // 转移创建者费用
        if (creatorFee > 0) {
            (bool creatorSuccess, ) = info.creator.call{value: creatorFee}("");
            require(creatorSuccess, "Creator fee transfer failed");
        }
        
        // 退还多余的支付
        if (msg.value > totalCost) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - totalCost}("");
            require(refundSuccess, "Refund failed");
        }
        
        emit MemeMinted(tokenAddr, msg.sender, info.perMint, totalCost, projectFee, creatorFee);
    }
    
    /**
     * @dev 获取已部署代币的数量
     * @return 已部署代币的总数
     */
    function getDeployedTokensCount() external view returns (uint256) {
        return deployedTokens.length;
    }
    
    /**
     * @dev 根据索引获取已部署的代币地址
     * @param index 代币在数组中的索引
     * @return 代币合约地址
     */
    function getDeployedToken(uint256 index) external view returns (address) {
        require(index < deployedTokens.length, "Index out of bounds");
        return deployedTokens[index];
    }
    
    /**
     * @dev 获取所有已部署的代币地址
     * @return 所有代币合约地址的数组
     */
    function getAllDeployedTokens() external view returns (address[] memory) {
        return deployedTokens;
    }
    
    /**
     * @dev 更新项目钱包地址（仅限所有者）
     * @param _newProjectWallet 新的项目钱包地址
     * @notice 只有合约所有者可以调用此函数
     */
    function updateProjectWallet(address _newProjectWallet) external onlyOwner {
        require(_newProjectWallet != address(0), "Project wallet cannot be zero address");
        projectWallet = _newProjectWallet;
    }
    
    /**
     * @dev 获取代币信息
     * @param tokenAddr 代币合约地址
     * @return 代币的详细信息结构体
     */
    function getTokenInfo(address tokenAddr) external view returns (TokenInfo memory) {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        return tokenInfo[tokenAddr];
    }
    
    /**
     * @dev 计算铸造代币的费用
     * @param tokenAddr 代币合约地址
     * @return totalCost 总费用
     * @return projectFee 平台费用
     * @return creatorFee 创建者费用
     */
    function getMintingCost(address tokenAddr) external view returns (uint256 totalCost, uint256 projectFee, uint256 creatorFee) {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        
        TokenInfo memory info = tokenInfo[tokenAddr];
        totalCost = info.perMint * info.price;
        projectFee = (totalCost * PROJECT_FEE_BPS) / BASIS_POINTS;
        creatorFee = totalCost - projectFee;
    }
}