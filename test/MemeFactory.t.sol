// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    address public projectWallet;
    address public creator;
    address public user1;
    address public user2;
    
    // Test parameters
    string constant SYMBOL = "PEPE";
    uint256 constant TOTAL_SUPPLY = 1000000 * 1e18; // 1M tokens
    uint256 constant PER_MINT = 1 * 1e18; // 1 token per mint
    uint256 constant PRICE = 1; // 1 wei per token unit (very small for testing)
    
    event MemeDeployed(
        address indexed tokenAddress,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    
    event MemeMinted(
        address indexed tokenAddress,
        address indexed minter,
        uint256 amount,
        uint256 totalPaid,
        uint256 projectFee,
        uint256 creatorFee
    );
    
    function setUp() public {
        projectWallet = makeAddr("projectWallet");
        creator = makeAddr("creator");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy factory
        factory = new MemeFactory(projectWallet);
        
        // Give users some ETH
        vm.deal(creator, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }
    
    function testDeployMeme() public {
        vm.startPrank(creator);
        
        // Test successful deployment
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // Verify token was deployed
        assertTrue(tokenAddr != address(0));
        
        // Verify token info
        MemeFactory.TokenInfo memory info = factory.getTokenInfo(tokenAddr);
        assertEq(info.symbol, SYMBOL);
        assertEq(info.totalSupply, TOTAL_SUPPLY);
        assertEq(info.perMint, PER_MINT);
        assertEq(info.price, PRICE);
        assertEq(info.creator, creator);
        assertTrue(info.exists);
        
        // Verify token contract
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.name(), "Meme Token");
        assertEq(token.totalSupplyLimit(), TOTAL_SUPPLY);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.price(), PRICE);
        assertEq(token.creator(), creator);
        assertEq(token.factory(), address(factory));
        
        vm.stopPrank();
    }
    
    function testDeployMemeInvalidParameters() public {
        vm.startPrank(creator);
        
        // Test empty symbol
        vm.expectRevert("Symbol cannot be empty");
        factory.deployMeme("", TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // Test zero total supply
        vm.expectRevert("Total supply must be greater than 0");
        factory.deployMeme(SYMBOL, 0, PER_MINT, PRICE);
        
        // Test zero per mint
        vm.expectRevert("Per mint must be greater than 0");
        factory.deployMeme(SYMBOL, TOTAL_SUPPLY, 0, PRICE);
        
        // Test per mint exceeds total supply
        vm.expectRevert("Per mint cannot exceed total supply");
        factory.deployMeme(SYMBOL, 1000, 2000, PRICE);
        
        vm.stopPrank();
    }
    
    function testMintMeme() public {
        // Deploy a meme token first
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        MemeToken token = MemeToken(tokenAddr);
        uint256 totalCost = PER_MINT * PRICE;
        uint256 projectFee = (totalCost * 100) / 10000; // 1%
        uint256 creatorFee = totalCost - projectFee;
        
        // Record initial balances
        uint256 initialProjectBalance = projectWallet.balance;
        uint256 initialCreatorBalance = creator.balance;
        uint256 initialUser1Balance = user1.balance;
        
        // Test successful minting
        vm.prank(user1);
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        // Verify token balance
        assertEq(token.balanceOf(user1), PER_MINT);
        assertEq(token.totalSupply(), PER_MINT);
        
        // Verify fee distribution
        assertEq(projectWallet.balance, initialProjectBalance + projectFee);
        assertEq(creator.balance, initialCreatorBalance + creatorFee);
        assertEq(user1.balance, initialUser1Balance - totalCost);
    }
    
    function testMintMemeWithRefund() public {
        // Deploy a meme token first
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        uint256 totalCost = PER_MINT * PRICE;
        uint256 overpayment = 0.5 ether;
        uint256 totalPaid = totalCost + overpayment;
        
        // Record initial balance
        uint256 initialUser1Balance = user1.balance;
        
        // Test minting with overpayment
        vm.prank(user1);
        factory.mintMeme{value: totalPaid}(tokenAddr);
        
        // Verify refund
        assertEq(user1.balance, initialUser1Balance - totalCost);
    }
    
    function testMintMemeInsufficientPayment() public {
        // Deploy a meme token first
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        uint256 totalCost = PER_MINT * PRICE;
        uint256 insufficientPayment = totalCost - 1;
        
        // Test insufficient payment
        vm.prank(user1);
        vm.expectRevert("Insufficient payment");
        factory.mintMeme{value: insufficientPayment}(tokenAddr);
    }
    
    function testMintMemeNonExistentToken() public {
        address fakeToken = makeAddr("fakeToken");
        
        vm.prank(user1);
        vm.expectRevert("Token does not exist");
        factory.mintMeme{value: 1 ether}(fakeToken);
    }
    
    function testMintMemeExceedsTotalSupply() public {
        // Deploy a meme token with small total supply
        uint256 smallTotalSupply = PER_MINT * 2; // Only allow 2 mints
        
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, smallTotalSupply, PER_MINT, PRICE);
        
        uint256 totalCost = PER_MINT * PRICE;
        
        // First mint should succeed
        vm.prank(user1);
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        // Second mint should succeed
        vm.prank(user2);
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        // Third mint should fail
        vm.prank(user1);
        vm.expectRevert("Cannot mint more tokens");
        factory.mintMeme{value: totalCost}(tokenAddr);
    }
    
    function testFeeDistribution() public {
        // Deploy a meme token
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        uint256 totalCost = PER_MINT * PRICE;
        uint256 expectedProjectFee = (totalCost * 100) / 10000; // 1%
        uint256 expectedCreatorFee = totalCost - expectedProjectFee;
        
        // Get minting cost from factory
        (uint256 calculatedTotalCost, uint256 calculatedProjectFee, uint256 calculatedCreatorFee) = 
            factory.getMintingCost(tokenAddr);
        
        // Verify calculations
        assertEq(calculatedTotalCost, totalCost);
        assertEq(calculatedProjectFee, expectedProjectFee);
        assertEq(calculatedCreatorFee, expectedCreatorFee);
        
        // Record initial balances
        uint256 initialProjectBalance = projectWallet.balance;
        uint256 initialCreatorBalance = creator.balance;
        
        // Mint tokens
        vm.prank(user1);
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        // Verify exact fee distribution
        assertEq(projectWallet.balance - initialProjectBalance, expectedProjectFee);
        assertEq(creator.balance - initialCreatorBalance, expectedCreatorFee);
        
        // Verify 1% goes to project
        uint256 actualProjectPercentage = (expectedProjectFee * 10000) / totalCost;
        assertEq(actualProjectPercentage, 100); // 1%
    }
    
    function testMultipleMints() public {
        // Deploy a meme token
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        MemeToken token = MemeToken(tokenAddr);
        uint256 totalCost = PER_MINT * PRICE;
        
        // Multiple users mint tokens
        vm.prank(user1);
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        vm.prank(user2);
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        vm.prank(user1);
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        // Verify balances
        assertEq(token.balanceOf(user1), PER_MINT * 2);
        assertEq(token.balanceOf(user2), PER_MINT);
        assertEq(token.totalSupply(), PER_MINT * 3);
    }
    
    function testFactoryQueries() public {
        // Initially no tokens
        assertEq(factory.getDeployedTokensCount(), 0);
        
        // Deploy some tokens
        vm.startPrank(creator);
        address token1 = factory.deployMeme("TOKEN1", TOTAL_SUPPLY, PER_MINT, PRICE);
        address token2 = factory.deployMeme("TOKEN2", TOTAL_SUPPLY, PER_MINT, PRICE);
        vm.stopPrank();
        
        // Verify count
        assertEq(factory.getDeployedTokensCount(), 2);
        
        // Verify individual tokens
        assertEq(factory.getDeployedToken(0), token1);
        assertEq(factory.getDeployedToken(1), token2);
        
        // Verify all tokens
        address[] memory allTokens = factory.getAllDeployedTokens();
        assertEq(allTokens.length, 2);
        assertEq(allTokens[0], token1);
        assertEq(allTokens[1], token2);
    }
    
    function testUpdateProjectWallet() public {
        address newProjectWallet = makeAddr("newProjectWallet");
        
        // Only owner can update
        vm.prank(user1);
        vm.expectRevert();
        factory.updateProjectWallet(newProjectWallet);
        
        // Owner can update
        factory.updateProjectWallet(newProjectWallet);
        assertEq(factory.projectWallet(), newProjectWallet);
        
        // Cannot set to zero address
        vm.expectRevert("Project wallet cannot be zero address");
        factory.updateProjectWallet(address(0));
    }
    
    function testTokenRemainingSupply() public {
        // Deploy a meme token
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        MemeToken token = MemeToken(tokenAddr);
        
        // Initially all supply is remaining
        assertEq(token.remainingSupply(), TOTAL_SUPPLY);
        assertTrue(token.remainingSupply() >= PER_MINT);
        
        // After one mint
        uint256 totalCost = PER_MINT * PRICE;
        vm.prank(user1);
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        assertEq(token.remainingSupply(), TOTAL_SUPPLY - PER_MINT);
        assertTrue(token.remainingSupply() >= PER_MINT);
    }
}