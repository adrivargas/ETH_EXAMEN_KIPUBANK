// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title KipuBank - Contrato de bóveda bancaria en ETH
/// @author Vargas
/// @notice Permite depósitos y retiros seguros con límites globales y por transacción.
/// @dev Ejemplo de buenas prácticas en Solidity: CEI, errores personalizados, NatSpec.
contract KipuBank {
    // ========= VARIABLES INMUTABLES =========

    /// @notice Límite global de depósitos permitido en el banco (wei).
    uint256 public immutable depoLimi;

    /// @notice Límite máximo de retiro por transacción (wei).
    uint256 public immutable retiroLimit;

    // ========= VARIABLES DE ALMACENAMIENTO =========

    /// @notice Total de ETH actualmente depositado en el contrato.
    uint256 public totalDeposits;

    /// @notice Registra el balance individual de cada usuario.
    mapping(address => uint256) private vault;

    /// @notice Número total de depósitos realizados.
    uint256 public depositCount;

    /// @notice Número total de retiros realizados.
    uint256 public retiroCount;

    // ========= EVENTOS =========

    /// @notice Emitido cuando un usuario deposita fondos.
    event Deposit(address indexed user, uint256 amount);

    /// @notice Emitido cuando un usuario retira fondos.
    event Retiro(address indexed user, uint256 amount);

    // ========= ERRORES PERSONALIZADOS =========

    /// @notice Error cuando el monto ingresado es cero.
    error ZeroAmount();

    /// @notice Error cuando se supera el tope global de depósitos.
    error DepoLimiReached();

    /// @notice Error cuando el usuario no tiene saldo suficiente.
    error InsufficientBalance(uint256 requested, uint256 available);

    /// @notice Error cuando el monto solicitado supera el límite de retiro.
    error RetiroLimitExceeded(uint256 requested, uint256 limit);

    /// @notice Error cuando la transferencia de ETH falla.
    error TransferFailed();

    // ========= CONSTRUCTOR =========

    /// @param _depoLimi Tope global de depósitos (wei).
    /// @param _retiroLimit Límite por retiro (wei).
    constructor(uint256 _depoLimi, uint256 _retiroLimit) {
        depoLimi = _depoLimi;
        retiroLimit = _retiroLimit;
    }

    // ========= MODIFICADORES =========

    /// @dev Verifica que el monto no sea cero.
    modifier onlyValidAmount(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }

    // ========= FUNCIONES EXTERNAS =========

    /// @notice Deposita ETH en la bóveda personal.
    /// @dev Sigue el patrón checks-effects-interactions.
    function deposit() external payable onlyValidAmount(msg.value) {
        if (totalDeposits + msg.value > depoLimi) revert DepoLimiReached();

        vault[msg.sender] += msg.value;
        totalDeposits += msg.value;
        depositCount++;

        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Retira ETH de la bóveda personal hasta el límite.
    /// @param _amount Cantidad a retirar (wei).
    function retiro(uint256 _amount) external onlyValidAmount(_amount) {
        uint256 balance = vault[msg.sender];
        if (_amount > balance) revert InsufficientBalance(_amount, balance);
        if (_amount > retiroLimit) revert RetiroLimitExceeded(_amount, retiroLimit);

        vault[msg.sender] = balance - _amount;
        totalDeposits -= _amount;
        retiroCount++;

        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) revert TransferFailed();

        emit Retiro(msg.sender, _amount);
    }

    /// @notice Consulta el balance en la bóveda personal.
    /// @return balance Balance actual del msg.sender.
    function getBalance() external view returns (uint256 balance) {
        return vault[msg.sender];
    }

    // ========= FUNCION PRIVADA =========

    /// @dev Calcula cuánto espacio queda hasta el límite global.
    function _calculateRemainingCap() private view returns (uint256) {
        return depoLimi - totalDeposits;
    }

    // ========= MANEJO DE ETH DIRECTO =========

    /// @dev Evita recibir ETH directamente sin usar deposit().
    receive() external payable {
        revert ZeroAmount();
    }

    fallback() external payable {
        revert ZeroAmount();
    }
}
