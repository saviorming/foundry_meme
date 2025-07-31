// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MemeFactory} from "../src/MemeFactory.sol";

/**
 * @title DeployMemeFactory
 * @dev Meme工厂合约部署脚本
 * @notice 用于部署MemeFactory合约到区块链网络
 * @author Meme Launch Platform Team
 */
contract DeployMemeFactory is Script {
    /**
     * @dev 主要部署函数
     * @notice 部署MemeFactory合约并记录相关信息
     * @notice 需要设置PRIVATE_KEY环境变量
     */
    function run() external {
        // 从环境变量获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 设置项目钱包地址（可以是部署者地址或其他指定地址）
        address projectWallet = vm.addr(deployerPrivateKey);
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署MemeFactory合约
        MemeFactory factory = new MemeFactory(projectWallet);
        
        // 停止广播
        vm.stopBroadcast();
        
        // 记录部署信息
        console.log(unicode"=== Meme Factory 部署完成 ===");
        console.log(unicode"MemeFactory 地址:", address(factory));
        console.log(unicode"MemeToken 实现合约地址:", factory.memeTokenImplementation());
        console.log(unicode"项目钱包地址:", factory.projectWallet());
        console.log(unicode"部署者地址:", vm.addr(deployerPrivateKey));
        console.log("================================");
    }
}