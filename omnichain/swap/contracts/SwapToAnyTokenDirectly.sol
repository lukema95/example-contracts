// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IWZETA.sol";
import "@zetachain/toolkit/contracts/OnlySystem.sol";
import "@zetachain/toolkit/contracts/shared/libraries/UniswapV2Library.sol";

contract SwapToAnyTokenDirectly is zContract, OnlySystem {
    SystemContract public systemContract;

    uint256 constant BITCOIN = 18332;

    constructor(address systemContractAddress) {
        systemContract = SystemContract(systemContractAddress);
    }

    struct Params {
        address target;
        bytes to;
        bool withdraw;
    }

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override onlySystem(systemContract) {
        Params memory params = Params({
            target: address(0),
            to: bytes(""),
            withdraw: true
        });

        if (context.chainID == BITCOIN) {
            params.target = BytesHelperLib.bytesToAddress(message, 0);
            params.to = abi.encodePacked(BytesHelperLib.bytesToAddress(message, 20));
            if (message.length >= 41) {
                params.withdraw = BytesHelperLib.bytesToBool(message, 40);
            }
        } else {
            (address targetToken, bytes memory recipient, bool withdrawFlag) = abi.decode(
                message,
                (address, bytes, bool)
            );
            params.target = targetToken;
            params.to = recipient;
            params.withdraw = withdrawFlag;
        }

        uint256 inputForGas;
        address gasZRC20;
        uint256 gasFee;

        if (params.withdraw) {
            (gasZRC20, gasFee) = IZRC20(params.target).withdrawGasFee();

            inputForGas = SwapHelperLib.swapTokensForExactTokens(
                systemContract,
                zrc20,
                gasFee,
                gasZRC20,
                amount
            );
        }

        uint256 amountIn = params.withdraw ? amount - inputForGas : amount;
        uint256 minOutAmount = getMintOutAmount(zrc20, params.target, amountIn);

        uint256 outputAmount = SwapHelperLib.swapExactTokensForTokensDirectly(
            systemContract,
            zrc20,
            params.withdraw ? amount - inputForGas : amount,
            params.target,
            minOutAmount
        );

        if (params.withdraw) {
            IZRC20(gasZRC20).approve(params.target, gasFee);
            IZRC20(params.target).withdraw(params.to, outputAmount);
        } else {
            IWETH9(params.target).transfer(address(uint160(bytes20(params.to))), outputAmount);
        }
    }

    function getMintOutAmount(address zrc20, address target, uint256 amountIn) public view returns (uint256 minOutAmount) {
        address[] memory path;

        path = new address[](2);
        path[0] = zrc20;
        path[1] = target;
        uint[] memory amounts1 = UniswapV2Library.getAmountsOut(systemContract.uniswapv2FactoryAddress(), amountIn, path);

        path = new address[](3);
        path[0] = zrc20;
        path[1] = systemContract.wZetaContractAddress();
        path[2] = target;
        uint[] memory amounts2 = UniswapV2Library.getAmountsOut(systemContract.uniswapv2FactoryAddress(), amountIn, path);

        minOutAmount = amounts1[amounts1.length - 1] > amounts2[amounts2.length - 1] ? amounts1[amounts1.length - 1] : amounts2[amounts2.length - 1];
    }
}
