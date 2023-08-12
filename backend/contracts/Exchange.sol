// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Контракт биржи наследует от ERC20, чтобы иметь возможность мнить токены провайдера ликвидности.
contract Exchange is ERC20 {

    // Адрес токена, который будет торговаться на бирже
    address public tokenAddress;

    constructor(address token) ERC20('ETH TOKEN LP Token', 'lpETHTOKEN') {
        require(token != address(0), 'Token address passed is null address');
        tokenAddress = token;
    }

    // Функция просто возвращает количество токенов в резерве
    function getReserve() public view returns(uint) {
        return ERC20(tokenAddress).balanceOf(address(this));
    }

    // Функция даёт возможность всем желающим добавить в ликвидность в торговую пару токенов и эфира.
    function addLiquidity(uint tokenAmount) public payable returns(uint) {
        uint lpTokensToMint;
        uint ethReserve = address(this).balance;
        uint tokenReserve = getReserve();

        ERC20 token = ERC20(tokenAddress);

        // Если в резерве нет токенов, то переводим их от пользователя
        // и минтим ему токены провайдера ликвидности в количестве равном предоставленному эфиру.
        // Таким образом первый поставщик ликвидности устанавливает соотношение токенов к эфиру, и, как следствие, цену токена.
        if (tokenReserve == 0) {
            token.transferFrom(msg.sender, address(this), tokenAmount);
            lpTokensToMint = ethReserve;
            _mint(msg.sender, lpTokensToMint);
            return lpTokensToMint;
        }

        // Если в резерве есть токены, то считаем пропорцию токенов к эфиру(пользователь не может внести ликвидность в соотношении отличным от существующего),
        // и проверяем что пользователь предоставил достаточное количество токенов.
        uint ethReserveBeforeCall = ethReserve - msg.value;
        uint proportionalTokenAmount = (msg.value * tokenReserve) / ethReserveBeforeCall;
        require(tokenAmount >= proportionalTokenAmount, 'Inefficient amount of tokens provided');

        // Переводим токены от пользователя и мнитим ему токены провайдера ликвидности в количестве расчитанном по пропорции с предоставленным эфиром.
        token.transferFrom(msg.sender, address(this), proportionalTokenAmount);
        lpTokensToMint = (totalSupply() * msg.value) / ethReserveBeforeCall;
        _mint(msg.sender, lpTokensToMint);
        return lpTokensToMint;
    }

    // Функция обмена токенов провайдера ликвидности на часть общих резервов эфира и токена
    // Таким образом пользователь может вывести свои предоставленные токены + вознаграждение
    function removeLiquidity(uint lpTokenAmount) public returns(uint, uint) {
        require(lpTokenAmount > 0, 'The amount of lpTokens must be greater then 0');

        uint ethReserve = address(this).balance;
        uint lpTokenSupply = totalSupply();

        // Расчитываем количество токенов и эфира, юзер может получить за свои токены провайдера ликвидности.
        uint ethToReturn = (lpTokenAmount * ethReserve) / lpTokenSupply;
        uint tokenToReturn = (lpTokenAmount * getReserve()) / lpTokenSupply;

        // Сжигаем токены провайдера ликвидности и переводим юзеру эфир и токены.
        _burn(msg.sender, lpTokenAmount);
        payable(msg.sender).transfer(ethToReturn);
        ERC20(tokenAddress).transfer(msg.sender, tokenToReturn);

        return (ethToReturn, tokenToReturn);
    }

    // Функция расчёта количества получаемых токенов при обмене по формуле xy = (x + dx)(y - dy)
    // с учётом комиссии в 1%
    function getOutputAmountFromSwap(
        uint inputAmount,
        uint inputReserve,
        uint outputReserve
    ) public pure returns(uint) {
        require(inputReserve > 0 && outputReserve > 0, 'Reserves must be greater then 0');

        uint inputAmountWithFee = inputAmount * 99;
        uint numerator = inputAmountWithFee * outputReserve;
        uint denominator = (inputReserve * 100) + inputAmountWithFee;

        return numerator / denominator;
    }

    // Функция обмена эфира на токены
    function ethToTokenSwap(uint minTokensToReceive) public payable {
        uint tokenReserve = getReserve();
        uint ethReserve = address(this).balance - msg.value;
        uint tokensToReceive = getOutputAmountFromSwap(msg.value, ethReserve, tokenReserve);

        require(tokensToReceive >= minTokensToReceive, 'Tokens received are less than minimum tokens expected');

        ERC20(tokenAddress).transfer(msg.sender, tokensToReceive);
    }

    // Функция обмена токенов на эфир
    function tokenToEthSwap(uint tokensToSwap, uint minEthToReceive) public {
        uint tokenReserve = getReserve();
        uint ethReserve = address(this).balance;
        uint ethToReceive = getOutputAmountFromSwap(tokensToSwap, tokenReserve, ethReserve);

        require(ethToReceive >= minEthToReceive, 'ETH received is less than minimum ETH expected');

        ERC20(tokenAddress).transferFrom(msg.sender, address(this), tokensToSwap);
        payable(msg.sender).transfer(ethToReceive);
    }
}


