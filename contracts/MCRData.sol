/* Copyright (C) 2017 NexusMutual.io

  This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

  This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/ */

pragma solidity 0.4.24;

import "./Iupgradable.sol";

import "./imports/DSInterface.sol";

import "./imports/openzeppelin-solidity/math/SafeMath.sol";


contract MCRData is Iupgradable, DSInterface {
    using SafeMath for uint;

    address public masterAddress;
    uint32 internal minMCRReq;
    uint32 internal sfX100000;
    uint32 internal growthStep;
    uint16 internal minCap;
    uint64 internal mcrFailTime;
    uint16 internal shockParameter;
    uint64 internal mcrTime;
    bytes4[] internal allCurrencies;


    struct McrData {
        uint32 mcrPercx100;
        uint32 mcrEtherx100;
        uint vFull; //Pool funds
        uint64 date;
    }

    McrData[] internal allMCRData;
    mapping(bytes8 => uint32) public allCurr3DaysAvg;
    address public notariseMCR;
    address public DAIFeed;
    uint private constant DECIMAL1E16 = uint(10) ** 16;
   

    constructor() public {
        growthStep = 1500000;
        sfX100000 = 140;
        mcrTime = 24 hours;
        mcrFailTime = 6 hours;
        minMCRReq = 0; //value in percentage e.g 60% = 60*100 
        allMCRData.push(McrData(0, 0, 0, 0));
        minCap = 1;
        shockParameter = 50;
    }

    modifier onlyOwner {
        require(ms.isOwner(msg.sender) == true);
        _;
    }

    /// @dev Changes address allowed to post MCR.
    function changeNotariseAdd(address _add) external onlyInternal {
        notariseMCR = _add;
    }

    /// @dev Sets minimum Cap.
    function changeMinCap(uint16 newCap) external onlyOwner {
        minCap = newCap;
    }

    /// @dev Sets Shock Parameter.
    function changeShockParameter(uint16 newParam) external onlyOwner {
        shockParameter = newParam;
    }

    /// @dev Changes Growth Step
    function changeGrowthStep(uint32 newGS) external onlyOwner {
        growthStep = newGS;
    }
    
    /// @dev Changes time period for obtaining new MCR data from external oracle query.
    function changeMCRTime(uint64 _time) external onlyInternal {
        mcrTime = _time;
    }

    /// @dev Sets MCR Fail time.
    function changeMCRFailTime(uint64 _time) external onlyInternal {
        mcrFailTime = _time;
    }

    /// @dev Changes minimum value of MCR required for the system to be working.
    /// @param minMCR in percentage. e.g 76% = 76*100
    function changeMinReqMCR(uint32 minMCR) external onlyInternal {
        minMCRReq = minMCR;
    }

    /// @dev Stores name of currency accepted in the system.
    /// @param curr Currency Name.
    function addCurrency(bytes4 curr) external onlyInternal {
        allCurrencies.push(curr);
    }

    /// @dev Changes scaling factor.
    function changeSF(uint32 val) external onlyInternal {
        sfX100000 = val;
    }
    
    /// @dev Updates the 3 day average rate of a currency.
    ///      To be replaced by MakeDaos on chain rates
    /// @param curr Currency Name.
    /// @param rate Average exchange rate X 100 (of last 3 days).
    function updateCurr3DaysAvg(bytes4 curr, uint32 rate) external onlyInternal {
        allCurr3DaysAvg[curr] = rate;
    }

    /// @dev Adds details of (Minimum Capital Requirement)MCR.
    /// @param mcrp Minimum Capital Requirement percentage (MCR% * 100 ,Ex:for 54.56% ,given 5456)
    /// @param vf Pool fund value in Ether used in the last full daily calculation from the Capital model.
    function pushMCRData(uint32 mcrp, uint32 mcre, uint vf, uint64 time) external onlyInternal {
        allMCRData.push(McrData(mcrp, mcre, vf, time));
    }

    /// @dev updates DAIFeed address.
    /// @param _add address of MKR feed.
    function changeDAIFeedAddress(address _add) external onlyOwner {
        DAIFeed = _add;
    }

    /// @dev Checks whether a given address can notaise MCR data or not.
    /// @param _add Address.
    /// @return res Returns 0 if address is not authorized, else 1.
    function isnotarise(address _add) external view returns(bool res) {
        res = false;
        if (_add == notariseMCR)
            res = true;
    }

    /// @dev Gets number of currencies that the system accepts.
    function getCurrLength() external view returns(uint16 len) {
        len = uint16(allCurrencies.length);
    }

    /// @dev Gets name of currency at a given index.
    function getCurrencyByIndex(uint16 index) external view returns(bytes4 curr) {
        curr = allCurrencies[index];
    }

    /// @dev Gets the average rate of a currency.
    /// @param curr Currency Name.
    /// @return rate Average rate X 100(of last 3 days).
    function getCurr3DaysAvg(bytes8 curr) external view returns(uint32 rate) {
        if(curr == "DAI")
        {
            DSInterface ds = DSInterface(DAIFeed);
            uint daiRate = uint(ds.read()).div(DECIMAL1E16);
            rate = uint32(daiRate);
        }
        else
            rate = allCurr3DaysAvg[curr];
    }

    /// @dev Gets the details of last added MCR.
    /// @return mcrPercx100 Total Minimum Capital Requirement percentage of that month of year(multiplied by 100).
    /// @return vFull Total Pool fund value in Ether used in the last full daily calculation.
    function getLastMCR() external view returns(uint32 mcrPercx100, uint32 mcrEtherx100, uint vFull, uint64 date) {
        uint index = allMCRData.length.sub(1);
        return (
            allMCRData[index].mcrPercx100,
            allMCRData[index].mcrEtherx100,
            allMCRData[index].vFull,
            allMCRData[index].date
        );
    }

    /// @dev Gets last Minimum Capital Requirement percentage of Capital Model
    /// @return val MCR% value,multiplied by 100.
    function getLastMCRPerc() external view returns(uint32 val) {
        val = allMCRData[allMCRData.length.sub(1)].mcrPercx100;
    }

    /// @dev Gets last Ether price of Capital Model
    /// @return val ether value,multiplied by 100.
    function getLastMCREther() external view returns(uint32 val) {
        val = allMCRData[allMCRData.length.sub(1)].mcrEtherx100;
    }

    /// @dev Gets Pool fund value in Ether used in the last full daily calculation from the Capital model.
    function getLastVfull() external view returns(uint vf) {
        vf = allMCRData[allMCRData.length.sub(1)].vFull;
    }

    /// @dev Gets last Minimum Capital Requirement in Ether.
    /// @return date of MCR.
    function getLastMCRDate() external view returns(uint64 date) {
        date = allMCRData[allMCRData.length.sub(1)].date;
    }

    /// @dev Gets details for token price calculation.
    function getTokenPriceDetails(bytes4 curr) external view returns(uint32 sf, uint32 gs, uint32 rate) {
        sf = sfX100000;
        gs = growthStep;
        rate = allCurr3DaysAvg[curr];
    }

    /// @dev Gets Scaling Factor.
    function getSFx100000() external view returns(uint32 sf) {
        sf = sfX100000;
    }

    /// @dev Gets Growth Step
    function getGrowthStep() external view returns(uint32 gs) {
        gs = growthStep;
    }

    /// @dev Gets minimum Cap.
    function getMinCap() external view returns(uint16 _minCap) {
        _minCap = minCap;
    }

    /// @dev Gets Shock Parameter.
    function getShockParameter() external view returns(uint16 _shock) {
        _shock = shockParameter;
    }

    /// @dev Gets time interval after which MCR calculation is initiated.
    function getMCRTime() external view returns(uint64 _time) {
        _time = mcrTime;
    }

    /// @dev Gets MCR Fail time.
    function getMCRFailTime() external view returns(uint64 _time) {
        _time = mcrFailTime;
    }

    /// @dev Gets minimum  value of MCR required.
    function getMinMCR() external view returns(uint32 mcr) {
        mcr = minMCRReq;
    }

    /// @dev Gets name of all the currencies accepted in the system.
    /// @return curr Array of currency's name.
    function getAllCurrencies() external view returns(bytes4[] curr) {
        return allCurrencies;
    }

    /// @dev Gets the total number of times MCR calculation has been made.
    function getMCRDataLength() external view returns(uint len) {
        len = allMCRData.length;
    }
 
    function changeDependentContractAddress() public onlyInternal {}

    
}
