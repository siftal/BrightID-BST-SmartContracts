pragma solidity ^0.5.0;

import "/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./BSToken.sol";
import "./BSSToken.sol";
import "./Finance.sol";
import "./CanReclaimToken.sol";


/**
 * @title BSST minter contract.
 */
contract BSSTMinter is Ownable, CanReclaimToken {
    using SafeMath for uint256;

    BSToken internal bsToken;
    BSSToken internal bssToken;
    ERC20 internal purchaseToken;

    uint256 public constant STEP = 25000;

    string private constant INSUFFICIENT_PAYMENT = "Insufficient payment";
    string private constant APPROVE_ERROR = "Approve error";
    string private constant MINT_ERROR = "Mint error";
    string private constant FINANCE_MESSAGE = "Revenue of BSS Token Sale";

    mapping(uint256 => uint256) private prices;

    event TokensPurchased(address buyer, uint256 price);
    event TokensClaimed(address account, uint256 amount);

    constructor(address bsTokenAddr, address bssTokenAddr, address purchaseTokenAddr, address financeAddr)
        public
    {
        prices[0] = 16 * 10**18;
        prices[1] = 25 * 10**18;
        prices[2] = 50 * 10**18;
        prices[3] = 100 * 10**18;
        bsToken = BSToken(bsTokenAddr);
        bssToken = BSSToken(bssTokenAddr);
        finance = Finance(financeAddr);
        purchaseToken = ERC20(purchaseTokenAddr);
    }

    /**
     * @notice Purchase BSS token.
     */
    function purchase()
        external
        returns (bool success)
    {
        uint256 totalSupply = bssToken.totalSupply();
        uint256 stepNumber = totalSupply.div(STEP);
        uint256 price = prices[stepNumber];
        uint256 availableTokens = (stepNumber + 1) * STEP - totalSupply;
        uint256 allowance = purchaseToken.allowance(msg.sender, address(this));
        require(price <= allowance, INSUFFICIENT_PAYMENT);

        uint256 bssAmount = allowance.div(price);
        if (availableTokens < bssAmount) {
            bssAmount = availableTokens;
        }
        uint256 purchaseAmount = bssAmount.mul(price);
        if (purchaseToken.transferFrom(msg.sender, address(this), purchaseAmount)) {
            require(purchaseToken.approve(address(finance), purchaseAmount), APPROVE_ERROR);

            finance.deposit(address(purchaseToken), purchaseAmount, FINANCE_MESSAGE);

            emit TokensPurchased(msg.sender, bssAmount);
            require(bssToken.mint(msg.sender, bssAmount), MINT_ERROR);

            return true;
        }
        return false;
    }

    /**
     * @notice claim BST
     */
    function claim()
        external
        returns (bool success)
    {
        uint256 claimableAmount = bssToken.claim(msg.sender);
        emit TokensClaimed(msg.sender, claimableAmount);
        require(bsToken.mint(msg.sender, claimableAmount), MINT_ERROR);
        return true;
    }

    /**
     * @notice Get current BSS token price.
     */
    function price()
        external
        view
        returns(uint256)
    {
        uint256 totalSupply = bssToken.totalSupply();
        uint256 stepNumber = totalSupply.div(STEP);
        return prices[stepNumber];
    }
}