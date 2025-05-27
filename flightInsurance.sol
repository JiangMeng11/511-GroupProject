// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlightInsurance {
    address public owner;

    struct Policy {
        string flightNumber;
        uint256 premium;
        uint256 payoutAmount;
        bool active;
        bool claimed;
    }

    event PolicyPurchased(address indexed customer, string flightNumber, uint256 premium);
    event ClaimPaid(address indexed customer, string flightNumber, uint256 amount);
    event FlightStatusUpdated(string flightNumber, bool delayed);

    mapping(address => Policy[]) public customerPolicies;
    mapping(string => bool) public flightDelayed;

    address public oracleAddress;
    mapping(string => uint256) public routeRiskMultiplier;

    uint256 public basePremium = 0.05 ether;
    uint256 public basePayoutMultiplier = 300; // 3x payout

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracleAddress, "Not authorized oracle");
        _;
    }

    constructor(address _oracleAddress) {
        owner = msg.sender;
        oracleAddress = _oracleAddress;

        // Set default risk multipliers
        routeRiskMultiplier["JFK-LAX"] = 150;
        routeRiskMultiplier["ORD-MIA"] = 120;
        routeRiskMultiplier["DEN-SEA"] = 180;
    }

    function calculatePremium(string memory route) public view returns (uint256) {
        uint256 multiplier = routeRiskMultiplier[route];
        if (multiplier == 0) multiplier = 100;
        return (basePremium * multiplier) / 100;
    }

    function buyInsurance(string memory flightNumber, string memory route) public payable {
        uint256 premium = calculatePremium(route);
        require(msg.value >= premium, "Insufficient premium payment");

        Policy memory newPolicy = Policy({
            flightNumber: flightNumber,
            premium: premium,
            payoutAmount: (premium * basePayoutMultiplier) / 100,
            active: true,
            claimed: false
        });

        customerPolicies[msg.sender].push(newPolicy);

        if (msg.value > premium) {
            payable(msg.sender).transfer(msg.value - premium);
        }

        emit PolicyPurchased(msg.sender, flightNumber, premium);
    }

    function updateFlightStatus(string memory flightNumber, bool delayed) public onlyOracle {
        flightDelayed[flightNumber] = delayed;
        emit FlightStatusUpdated(flightNumber, delayed);
    }

    function ownerUpdateFlightStatus(string memory flightNumber, bool delayed) public onlyOwner {
        flightDelayed[flightNumber] = delayed;
        emit FlightStatusUpdated(flightNumber, delayed);
    }

    function claimPayout(uint256 policyIndex) public {
        require(policyIndex < customerPolicies[msg.sender].length, "Invalid policy index");

        Policy storage policy = customerPolicies[msg.sender][policyIndex];
        require(policy.active, "Policy not active");
        require(!policy.claimed, "Already claimed");
        require(flightDelayed[policy.flightNumber], "Flight not delayed");

        policy.claimed = true;
        payable(msg.sender).transfer(policy.payoutAmount);

        emit ClaimPaid(msg.sender, policy.flightNumber, policy.payoutAmount);
    }

    function getCustomerPolicies(address customer) public view returns (Policy[] memory) {
        return customerPolicies[customer];
    }

    function withdrawFunds() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function setOracle(address _newOracle) public onlyOwner {
        oracleAddress = _newOracle;
    }

    function setRouteRisk(string memory route, uint256 multiplier) public onlyOwner {
        routeRiskMultiplier[route] = multiplier;
    }

    receive() external payable {}

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
