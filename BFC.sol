pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FoisonCoin is ERC20 {
    using SafeMath for uint256;

    struct Record {
        uint256 blockId;
        uint256 amount; // 
    }

    struct ExchangeRate {
        uint256 blockId;
        int256 rate;
    }

    // constants
    uint256 private constant E18 = 1e18;
    uint256 private constant E = 1e8;
    uint256 private constant E20 = 20 * E * E18;
    uint256 private constant E45 = 45 * E * E18;
    uint256 private constant E60 = 60 * E * E18;
    uint256 private constant E70 = 70 * E * E18;
    uint256 private constant E15 = 15 * E * E18;
    uint256[2][5] private rates = [
        [uint256(66), uint256(100000)],
        [uint256(33), uint256(100000)],
        [uint256(165), uint256(10000000)],
        [uint256(825), uint256(100000000)],
        [uint256(4125), uint256(1000000000)]
    ];

    // account
    // 
    address private constant USDTADR =
        0xF0fa82Bc9Bc443adD29Ef454B679fb938C56D7AF;

    address private _owner;
    address private _firstAdr; // 
    address private _usdtAdr; // 
    address private _bustAdr; // 
    // rasie pool
    bool private _isRaising = true;
    uint256 private _rasieTotal = 5 * E * E18;
    uint256[2][3] private exchangeRates = [
        [uint256(57), 5 * E * E18],
        [uint256(64), 5 * E * E18],
        [uint256(72), 5 * E * E18]
    ];
    uint256 private cur_rate_idx = 0;

    // 
    uint256 private _mintTotal = 0; // 
    mapping(address => Record) private records; // 
    uint256[] private breakChangeIds; // 0->20->45->60->70， 
    event Pledge(address indexed _from, uint256 _value);
    event Withdraw(
        address indexed _from,
        uint256 _value,
        uint256 _totalMint,
        address _recommender,
        uint256 _recommenderValue
    );
    event UpdateMintMount(uint256 blockId, uint256 _value); //  breakchange
    event RaiseSucc(
        address indexed _from,
        uint256 _value,
        uint256 _rasieTotal,
        address _recommender,
        uint256 _recommenderValue,
        address _usdtFrom
    ); // 

    // 0xe8df8472b949eb9425a28e4e9f1a70494f077325
    constructor(
        address authUser,
        address firstCtr,
        address usdtCtr,
        address busdCtr
    ) ERC20("Big Foison Coin", "BFC") {
        _mint(authUser, 15 * E * E18);
        _owner = msg.sender;
        _firstAdr = firstCtr;
        _usdtAdr = usdtCtr;
        _bustAdr = busdCtr;
    }

    fallback() external {}

    receive() external payable {}

    // usdtFrom: 
    // amount: 
    // recommender: 
    function raise(
        uint256 amount,
        address usdtFrom,
        address recommender
    ) public returns (uint256) {
        require(checkIsValidUsdt(usdtFrom), "invalid usdt contracts address");

        uint256 curRate = usdtFrom == address(_firstAdr)
            ? 1
            : exchangeRates[cur_rate_idx][0];
        uint256 curUsdtAmount = usdtFrom == address(_firstAdr) ? amount : (curRate * amount) / uint256(10000);

        require(
            ERC20(usdtFrom).allowance(msg.sender, address(this)) >=
                curUsdtAmount,
            "token need allowance > amount"
        );
        require(
            ERC20(usdtFrom).balanceOf(msg.sender) >= curUsdtAmount,
            "rasie amount must less than balance"
        );
        require(amount >= 0, "amount must greater than 0");

        // 
        if (usdtFrom != address(_firstAdr)) {
            require(_isRaising, "raise is over!!");
            require(amount >= 100 * E18, "amount should be larger than 100");
        }

        require(E15 >= amount, "rasie pool must greater than amount ");

        ERC20(usdtFrom).transferFrom(
            msg.sender,
            address(USDTADR),
            curUsdtAmount
        ); //  
        mint(msg.sender, amount); // 

        // 
        if (recommender != address(0) && usdtFrom != address(_firstAdr)) {
            uint256 toRecAmount = amount.div(10);
            mint(recommender, toRecAmount);
            _rasieTotal -= toRecAmount;
        }

        if (usdtFrom != address(_firstAdr)) {
            _rasieTotal -= amount; // 
        }

        emit RaiseSucc(
            msg.sender,
            amount,
            _rasieTotal,
            recommender,
            amount.div(10),
            usdtFrom
        );
        return amount;
    }

    function totalSupply() public override pure  returns (uint256) {
        return 100 * E * E18;
    }

    function checkIsValidUsdt(address adr) private view returns (bool) {
        return adr == _firstAdr || adr == _usdtAdr || adr == _bustAdr;
    }

    function isRaiseOver() public view returns (bool) {
        return _isRaising == false;
    }

    function getCurrentRaiseRate() public view returns (uint256) {
        return exchangeRates[cur_rate_idx][0];
    }

    // 
    function startNextTerm() public returns (uint256) {
        require(msg.sender == _owner, "permission refuse");

        require(isRaiseOver(), "current raise is not over!");

        if (cur_rate_idx < 2) {
            cur_rate_idx++;
        }

        _rasieTotal = exchangeRates[cur_rate_idx][1];
        _isRaising = true;
        return exchangeRates[cur_rate_idx][0];
    }

    // 募集结束
    function rasieOver(address promoteUser) public {
        require(msg.sender == _owner, "permission refuse");

        // transfer to rasie
        if (_rasieTotal > 0) {
            mint(promoteUser, _rasieTotal);
        }

        _rasieTotal = 0;
        _isRaising = false;
    }

    function getCurrentRasieMount() public view returns (uint256) {
        return _rasieTotal;
    }

    function mint(address recipient, uint256 amount) private {
        _mint(recipient, amount);
    }

    // 
    function pledge(uint256 amount) public {
        require(
            allowance(msg.sender, address(this)) >= amount,
            "token need allowance > amount"
        );
        require(balanceOf(msg.sender) >= amount, "user balance need > amount");

        require(
            amount > 100 * 1000 * E18,
            "pledge amount must be larger than 100w"
        );

        require(!checkIsPledge(msg.sender), "tokenAdr is in pledge");

        _transfer(msg.sender, address(this), amount);

        // 
        records[msg.sender].blockId = block.number;
        records[msg.sender].amount = amount;
        emit Pledge(msg.sender, amount);
    }

    function checkIsPledge(address tokenAdr) public view returns (bool) {
        return records[tokenAdr].blockId != 0;
    }

    // 
    function withdraw(address recommender) public returns (uint256[2] memory) {
        require(records[msg.sender].amount >= 0, "user has not pledge yet");

        uint256 interest = getInterest(
            records[msg.sender].amount,
            block.number,
            records[msg.sender].blockId
        );
        uint256 amount = records[msg.sender].amount;
        uint256 amountWithInterest = amount + interest;

        // 
        pay(interest, amount);
        updateMintAmount(interest);
        if (recommender != address(0)) {
            mint(recommender, (interest * 5) / 10);
            updateMintAmount((interest * 5) / 10);
        }

        emit Withdraw(
            msg.sender,
            amount,
            interest,
            recommender,
            (interest * 5) / 10
        );

        //
        records[msg.sender].blockId = 0;
        records[msg.sender].amount = 0;
        return [amount, interest];
    }

    function pay(uint256 interest, uint256 amount) private {
        mint(msg.sender, interest);
        _transfer(address(this), msg.sender, amount);
    }

    // 

    function updateMintAmount(uint256 mount) private {
        uint256 nextMount = _mintTotal + mount;

        uint256 startIdx = getChangeIdx(_mintTotal);
        uint256 endIdx = getChangeIdx(nextMount);

        if (endIdx > startIdx) {
            updateExchangeIds(block.number, [startIdx, endIdx]);
        }

        _mintTotal = nextMount;
        emit UpdateMintMount(block.number, _mintTotal);
    }

    function updateExchangeIds(uint256 blockId, uint256[2] memory startAndEnd)
        private
    {
        uint256 start = startAndEnd[0];
        uint256 end = startAndEnd[1];

        for (uint256 i = start; i < end; i++) {
            breakChangeIds[i] = blockId;
        }
    }

    // 
    function getInterest(
        uint256 amount,
        uint256 endId,
        uint256 startId
    ) public view returns (uint256) {
        uint256 changeTimes = breakChangeIds.length;
        uint256 intersts = 0;
        uint256 curId = startId;
        uint256 i = 0;
        for (i = 0; i < changeTimes; i++) {
            if (breakChangeIds[i] > curId) {
                intersts +=
                    (amount * getDay(breakChangeIds[i], curId) * rates[i][0]) /
                    rates[i][1] /
                    100000;
            }
            curId = breakChangeIds[i];
        }

        intersts +=
            (amount * getDay(endId, curId) * rates[i][0]) /
            rates[i][1] /
            100000;
        return intersts;
    }

    function getCurrentInterest(address tokenAdr)
        public
        view
        returns (uint256[2] memory)
    {
        require(checkIsPledge(tokenAdr), "token needs in pledge");

        uint256 amount = records[tokenAdr].amount;

        return [
            amount,
            getInterest(amount, block.number, records[tokenAdr].blockId)
        ];
    }

    function getDay(uint256 endId, uint256 startId)
        public
        pure
        returns (uint256)
    {
        require(endId >= startId, "endId must be larger than startId");
        return ((endId - startId) * 100000) / 28800; // 
    }

    // 
    function getChangeIdx(uint256 mount) private pure returns (uint256) {
        if (mount < E20) return 0;
        if (mount >= E20 && mount < E45) return 1;
        if (mount >= E45 && mount < E60) return 2;
        if (mount >= E60 && mount < E70) return 3;

        return 4;
    }

    // 
    function getMintTotalAmount() public view returns (uint256) {
        return _mintTotal;
    }
}
