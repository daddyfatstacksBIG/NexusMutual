const MCR = artifacts.require('MCR');
const Pool1 = artifacts.require('Pool1Mock');
const Pool2 = artifacts.require('Pool2');
const PoolData = artifacts.require('PoolData');
const DAI = artifacts.require('MockDAI');
const NXMToken = artifacts.require('NXMToken');
const MemberRoles = artifacts.require('MemberRoles');
const NXMaster = artifacts.require('NXMaster');

const { assertRevert } = require('./utils/assertRevert');
const { advanceBlock } = require('./utils/advanceToBlock');
const { ether } = require('./utils/ether');

const CA_ETH = '0x45544800';
const CA_DAI = '0x44414900';

let mcr;
let pd;
let tk;
let p1;
let balance_DAI;
let balance_ETH;
let nxms;
let mr;
let cad;
let p2;

const BigNumber = web3.BigNumber;
require('chai')
  .use(require('chai-bignumber')(BigNumber))
  .should();

contract('MCR', function([owner, notOwner]) {
  before(async function() {
    await advanceBlock();
    mcr = await MCR.deployed();
    tk = await NXMToken.deployed();
    p2 = await Pool2.deployed();
    p1 = await Pool1.deployed();
    pd = await PoolData.deployed();
    cad = await DAI.deployed();
    nxms = await NXMaster.deployed();
    mr = await MemberRoles.at(await nxms.getLatestAddress('0x4d52'));
  });

  describe('Token Price Calculation', function() {
    let tp_eth;
    let tp_dai;

    before(async function() {
      await mr.payJoiningFee(notOwner, {
        from: notOwner,
        value: 2000000000000000
      });
      await p2.upgradeInvestmentPool(owner);
      await p1.upgradeCapitalPool(owner);
      await p1.sendTransaction({ from: owner, value: 90000000000000000000 });
      await mr.kycVerdict(notOwner, true);
      await mcr.addMCRData(
        9000,
        100 * 1e18,
        90000000000000000000,
        ['0x455448', '0x444149'],
        [100, 15517],
        20190219
      );

      await pd.changeGrowthStep(5203349);
      await pd.changeSF(1948);
    });
    it('single tranche 0.1ETH', async function() {
      let dataaa = await pd.getTokenPriceDetails('ETH');
      let x = await tk.balanceOf(notOwner);
      await p1.buyToken({ from: notOwner, value: 100000000000000000 });
      let y = await tk.balanceOf(notOwner);
      console.log('single tranche 0.1ETH ==> ', parseFloat(y - x) / 1e18);
      ((y - x) / 1e18).toFixed(2).should.be.bignumber.equal(5.13);
    });
    it('multiple tranches 100ETH', async function() {
      let x = await tk.balanceOf(notOwner);
      await p1.buyToken({
        from: notOwner,
        value: 100000000000000000000
      });
      let y = await tk.balanceOf(notOwner);
      console.log('multiple tranches 100ETH ==> ', parseFloat(y - x) / 1e18);
      ((y - x) / 1e18).toFixed(2).should.be.bignumber.equal(5114.54);
    });
  });

  describe('Token Price Calculation2', function() {
    let tp_eth;
    let tp_dai;

    before(async function() {
      await p2.upgradeInvestmentPool(owner);
      await p1.upgradeCapitalPool(owner);
      await p1.sendTransaction({ from: owner, value: 10 * 1e18 });
      await mcr.addMCRData(
        1000,
        100 * 1e18,
        10 * 1e18,
        ['0x455448', '0x444149'],
        [100, 14800],
        20190219
      );

      await pd.changeGrowthStep(5203349);
      await pd.changeSF(1948);
    });
    it('single tranches 15 times Buy tokens', async function() {
      let x;
      let y;
      for (let i = 0; i < 15; i++) {
        console.log(
          'token rate 1ETH =  ',
          1e18 / parseFloat(await mcr.calculateTokenPrice('ETH'))
        );
        x = await tk.balanceOf(notOwner);
        await p1.buyToken({ from: notOwner, value: 10 * 1e18 });
        y = await tk.balanceOf(notOwner);
        console.log('single tranche 10ETH ==> ', parseFloat(y - x) / 1e18);
      }
    });
  });
});