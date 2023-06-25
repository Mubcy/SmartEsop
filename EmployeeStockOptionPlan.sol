pragma solidity ^0.8.0;

contract EmployeeStockOptionPlan {
    address private owner;
    
    struct OptionGrant {
        uint256 totalOptions;       // Total number of options granted
        uint256 vestedOptions;      // Number of options vested
        uint256 vestingStartTime;   // Start time of the vesting period (in UNIX timestamp)
        uint256 vestingDuration;    // Duration of the vesting period (in seconds)
        uint256 cliffDuration;      // Cliff duration in seconds
        bool transferRestricted;    // Flag to indicate if transfers are restricted
    }
    
    mapping(address => OptionGrant) private optionGrants;
    
    event StockOptionsGranted(address indexed employee, uint256 totalOptions, uint256 vestingStartTime, uint256 vestingDuration, uint256 cliffDuration, bool transferRestricted);
    event VestingScheduleSet(address indexed employee, uint256 vestingDuration, uint256 cliffDuration, bool transferRestricted);
    event OptionsExercised(address indexed employee, uint256 exercisedOptions);
    event OptionsTransferred(address indexed from, address indexed to, uint256 transferredOptions);

    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyEmployee() {
        require(optionGrants[msg.sender].totalOptions > 0, "Not an employee or options not granted");
        _;
    }
    
    /**
     * @dev Grants stock options to an employee by specifying their address and the number of options.
     * Emits a StockOptionsGranted event to log the grant of stock options.
     */
    function grantStockOptions(address employee, uint256 totalOptions) external onlyOwner {
        require(employee != address(0), "Invalid employee address");
        require(totalOptions > 0, "Total options must be greater than zero");
        require(optionGrants[employee].totalOptions == 0, "Options already granted to this employee");

        optionGrants[employee].totalOptions = totalOptions;
        
        emit StockOptionsGranted(employee, totalOptions, 0, 0, 0, false);
    }
    
    /**
     * @dev Sets the vesting schedule for an employee's options.
     * Emits a VestingScheduleSet event to log the setting of the vesting schedule.
     */
    function setVestingSchedule(address employee, uint256 vestingDuration, uint256 cliffDuration, bool transferRestricted) external onlyOwner {
        require(employee != address(0), "Invalid employee address");
        require(optionGrants[employee].totalOptions > 0, "No options granted to this employee");
        
        OptionGrant storage grant = optionGrants[employee];
        
        grant.vestingStartTime = block.timestamp;
        grant.vestingDuration = vestingDuration;
        grant.cliffDuration = cliffDuration;
        grant.transferRestricted = transferRestricted;
        
        emit VestingScheduleSet(employee, vestingDuration, cliffDuration, transferRestricted);
    }
    
    /**
     * @dev Allows an employee to exercise their vested options.
     * Emits an OptionsExercised event to log the exercise of options.
     */
    function exerciseOptions() external onlyEmployee {
        OptionGrant storage grant = optionGrants[msg.sender];
        
        require(grant.vestingStartTime > 0, "Vesting schedule not set");
        require(grant.vestedOptions == 0, "Options already vested");
        require(block.timestamp >= grant.vestingStartTime + grant.cliffDuration, "Cliff period has not passed yet");
        
        uint256 timeSinceVestingStart = block.timestamp - grant.vestingStartTime;
        uint256 vestedOptions = (timeSinceVestingStart * grant.totalOptions) / grant.vestingDuration;
        
        if (vestedOptions > grant.totalOptions) {
            vestedOptions = grant.totalOptions;
        }
        
        grant.vestedOptions = vestedOptions;
        
        emit OptionsExercised(msg.sender, vestedOptions);
    }
    
    /**
     * @dev Retrieves the number of vested options for an employee.
     */
    function getVestedOptions(address employee) external view returns (uint256) {
        return optionGrants[employee].vestedOptions;
    }
    
    /**
     * @dev Retrieves the number of exercised options for an employee.
     */
    function getExercisedOptions(address employee) external view returns (uint256) {
        return optionGrants[employee].totalOptions - optionGrants[employee].vestedOptions;
    }
    
    /**
     * @dev Allows an employee to transfer their vested options to another eligible employee,
     * subject to any transfer restrictions specified in the vesting schedule.
     * Emits an OptionsTransferred event to log the transfer of options.
     */
    function transferOptions(address to, uint256 amount) external onlyEmployee {
        OptionGrant storage grantFrom = optionGrants[msg.sender];
        OptionGrant storage grantTo = optionGrants[to];
        
        require(to != address(0), "Invalid recipient address");
        require(grantFrom.transferRestricted == false, "Transfer of options is restricted");
        require(amount <= grantFrom.vestedOptions, "Insufficient vested options");
        
        grantFrom.vestedOptions -= amount;
        grantTo.vestedOptions += amount;
        
        emit OptionsTransferred(msg.sender, to, amount);
    }
}
