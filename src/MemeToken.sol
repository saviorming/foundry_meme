// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MemeToken
 * @dev Meme代币的ERC20实现
 * @notice 这是一个使用最小代理模式的代币合约，用于高效部署Meme代币
 */
contract MemeToken is ERC20, Ownable {
    // 代币总供应量上限
    uint256 public totalSupplyLimit;
    
    // 每次铸造的代币数量
    uint256 public perMint;
    
    // 每个代币单位的价格（以wei为单位）
    uint256 public price;
    
    // 代币创建者地址
    address public creator;
    
    // 工厂合约地址
    address public factory;
    
    // 代币符号（私有变量，用于动态返回）
    string private _tokenSymbol;
    
    // 初始化状态标记
    bool private initialized;
    
    /**
     * @dev 只允许工厂合约调用的修饰符
     */
    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory can call this function");
        _;
    }
    
    /**
     * @dev 构造函数 - 创建实现合约
     * @notice 这是实现合约，将被克隆使用
     * 设置为已初始化状态，防止实现合约被误用
     * 将所有权转移给死地址，确保实现合约不能被操作
     */
    constructor() ERC20("Meme Token Implementation", "IMPL") Ownable(address(0xdead)) {
        // 标记实现合约为已初始化，防止被初始化
        initialized = true;
    }
    
    /**
     * @dev 初始化代币（工厂克隆后调用）
     * @param _symbol 代币符号
     * @param _totalSupply 总供应量上限
     * @param _perMint 每次铸造数量
     * @param _price 每个代币单位的价格（wei）
     * @param _creator 代币创建者地址
     * @param _factory 工厂合约地址
     * @notice 只能被调用一次，用于初始化克隆的代币合约
     */
    function initialize(
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator,
        address _factory
    ) external {
        // 确保未被初始化过
        require(!initialized, "Already initialized");
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_perMint > 0, "Per mint must be greater than 0");
        require(_perMint <= _totalSupply, "Per mint cannot exceed total supply");
        require(_creator != address(0), "Creator cannot be zero address");
        require(_factory != address(0), "Factory cannot be zero address");
        
        // 对于克隆合约，initialized初始为false
        // 只有在成功初始化后才设置为true
        initialized = true;
        
        // 设置代币参数
        _tokenSymbol = _symbol;
        totalSupplyLimit = _totalSupply;
        perMint = _perMint;
        price = _price;
        creator = _creator;
        factory = _factory;
        
        // 将所有权转移给创建者
        _transferOwnership(_creator);
    }
    
    /**
     * @dev Override name function to return dynamic name
     */
    function name() public pure override returns (string memory) {
        return "Meme Token";
    }
    
    /**
     * @dev 返回代币符号
     * @return 代币符号字符串
     * @notice 重写ERC20的symbol函数，返回初始化时设置的符号
     */
    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }
    
    /**
     * @dev 铸造代币（只能由工厂合约调用）
     * @param to 接收代币的地址
     * @param amount 铸造数量
     * @notice 确保不超过总供应量限制
     */
    function mint(address to, uint256 amount) external onlyFactory {
        require(totalSupply() + amount <= totalSupplyLimit, "Exceeds total supply limit");
        _mint(to, amount);
    }
    
    /**
     * @dev 获取剩余可铸造的代币数量
     * @return 剩余供应量
     */
    function remainingSupply() external view returns (uint256) {
        return totalSupplyLimit - totalSupply();
    }
}