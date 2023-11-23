const { expect } = require("chai");

describe("ERC20FactoryProxyTest", () => {
  // Wallet accounts
  let owner;
  let client;
  let airdropWallet;
  let claimer1;
  let claimer2;
  let claimer3;
  let campaignEOA;
  let txFeeReceiver;
  let costReceiver;

  // Campaign parameters
  let duration = 90;
  let campaignID = "TEST1234";
  let tokenIDs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  let tokenAmount = 0; //ethers.utils.parseEther("10");
  let etherAmount = ethers.utils.parseEther("0.3");
  let numberOfLinks = 0;

  // Contract instances
  let proxiedERCImpleInstance;
  let ERCImpleInstance, ERCImpleContract;
  let ERCProxyContract;
  let ERCProxyInstance;
  let TokenContract;
  let TokenInstance;
  let FactoryContract;
  let FactoryInstance;
  let proxyContractAddress;

  // Common variables
  let airdropLinks;

  // Utility functions for deploying contracts
  async function deployToken() {
    const tokenContract = await ethers.getContractFactory("NFT");
    const tokenInstance = await tokenContract.connect(client).deploy({
      gasLimit: 7000000,
    });
    await tokenInstance.deployed();
    console.log("Token contract address:", tokenInstance.address);
    return { tokenContract, tokenInstance };
  }

  async function deployERCImple() {
    const ercImpleContract = await ethers.getContractFactory("ERCImple");
    const ercImpleInstance = await ercImpleContract.connect(owner).deploy({
      gasLimit: 7000000,
    });
    await ercImpleInstance.deployed();

    console.log("Implementation contract address:", ercImpleInstance.address);
    return { ercImpleContract, ercImpleInstance };
  }

  async function deployFactory() {
    const factoryContract = await ethers.getContractFactory("ERCFactory");
    const factoryInstance = await factoryContract.connect(owner).deploy({
      gasLimit: 7000000,
    });
    await factoryInstance.deployed();

    console.log("Factory contract address:", factoryInstance.address);
    return { factoryContract, factoryInstance };
  }

  // Deploy contracts and set up shared variables before tests
  before(async () => {
    [
      owner,
      client,
      airdropWallet,
      claimer1,
      claimer2,
      claimer3,
      campaignEOA,
      txFeeReceiver,
      costReceiver,
    ] = await ethers.getSigners();

    const { tokenInstance, tokenContract } = await deployToken();
    TokenContract = tokenContract;
    TokenInstance = tokenInstance;

    const { ercImpleInstance, ercImpleContract } = await deployERCImple();
    ERCImpleContract = ercImpleContract;
    ERCImpleInstance = ercImpleInstance;

    const { factoryContract, factoryInstance } = await deployFactory();
    FactoryContract = factoryContract;
    FactoryInstance = factoryInstance;
  });

  describe("Check Param ", () => {
    it("clientBalance100", async () => {
      const clientBalance = await TokenInstance.balanceOf(client.address);
      console.log("clientBalance", clientBalance);
      expect(clientBalance).to.equal(100);
    });
  });

  describe("1. Approve", () => {
    it("Approve token to proxy contract from client", async () => {
      await TokenInstance.setApprovalForAll(FactoryInstance.address, true);
      const isApproved = await TokenInstance.isApprovedForAll(
        client.address,
        FactoryInstance.address
      );
      expect(isApproved).to.equal(true);
    });
  });

  describe("2. Create ProxyContract", async () => {
    it("Create ProxyContract", async () => {
      // 팩토리 컨트랙트 통해 프록시 컨트랙트 생성
      const campaignParams = {
        contractType: 1,
        client: client.address,
        campaignEOA: campaignEOA.address,
        campaignID,
        numberOfLinks: tokenIDs.length,
        duration,
        tokenAddress: ethers.constants.AddressZero,
        tokenAmount,
        nftAddress: TokenInstance.address,
        tokenIDs: tokenIDs,
        etherAmount,
      };
      console.log("campaignParams", campaignParams);
      const paymentParams = {
        txFee: ethers.utils.parseEther("0.01"), // 0.01 ether
        txFeeReceiver: txFeeReceiver.address,
        cost: ethers.utils.parseEther("0.1"), // 0.1 ether
        costReceiver: costReceiver.address,
      };

      let txFee = ethers.utils.parseEther("0.1");
      let cost = ethers.utils.parseEther("0.2");
      const createERCProxyTx = await FactoryInstance.connect(
        client
      ).createAndInitializeERCProxy(
        ERCImpleInstance.address,
        campaignParams,
        paymentParams,
        { value: etherAmount.add(txFee).add(cost) }
      );
      const receipt = await createERCProxyTx.wait();
      console.log("receipt", receipt);
      // 이벤트 로그에서 프록시 컨트랙트 주소 가져오기
      const event = receipt.events.find((e) => e.event === "ERCProxyDeployed");
      proxyContractAddress = event.args.proxyAddress;

      // 프록시 컨트랙트 주소로 Implentation 컨트랙트 연결
      console.log("Proxy contract address:", proxyContractAddress);
      proxiedERCImpleInstance = await ERCImpleContract.attach(
        proxyContractAddress
      );

      // 배포후 변수에 잘 이니셜라이즈 되었는지 확인
      const returnedCampaignID = await proxiedERCImpleInstance.campaignID();
      const returnedClient = await proxiedERCImpleInstance.client();
      const returnedBalance = await proxiedERCImpleInstance
        .connect(client)
        .getBalance();
      // console.log({
      //   factoryAddress: FactoryInstance.address,
      //   client: client.address,
      //   returnedClient,
      //   returnedCampaignID,
      //   returnedBalance,
      // });
      expect(returnedCampaignID, "Check campaignID").to.equal(campaignID);
      expect(returnedClient, "Check client address").to.equal(client.address);
      expect(returnedBalance.nftBalance, "Check token balance").to.equal(
        tokenIDs.length
      );
      expect(returnedBalance.etherBalance, "Check ether balance").to.equal(
        etherAmount
      );
    });
  });

  describe("3. Check Funds", () => {
    it("Call TransferFund", async () => {
      console.log(">>>>>>>>>>", client.address);
      const beforeClientTokenBalance = await TokenInstance.balanceOf(
        client.address
      );
      const beforeContractTokenBalance = await TokenInstance.balanceOf(
        proxiedERCImpleInstance.address
      );

      const afterClientTokenBalance = await TokenInstance.balanceOf(
        client.address
      );
      const afterContractTokenBalance = await TokenInstance.balanceOf(
        proxiedERCImpleInstance.address
      );
      console.log(
        "before client Token balance:",
        ethers.utils.formatEther(beforeClientTokenBalance).toString()
      );
      console.log(
        "before contract Token balance:",
        ethers.utils.formatEther(beforeContractTokenBalance).toString()
      );
      console.log(
        "after client Token balance:",
        ethers.utils.formatEther(afterClientTokenBalance).toString()
      );
      console.log(
        "after contract Token balance:",
        ethers.utils.formatEther(afterContractTokenBalance).toString()
      );
      // 컨트랙트 잔액 체크
      const dropContractBalance = await proxiedERCImpleInstance
        .connect(client)
        .getBalance();
      console.log({ dropContractBalance: dropContractBalance.toString() });
      const tokenBalance = dropContractBalance.tokenBalance;
      const nftBalance = dropContractBalance.nftBalance;
      const etherBalance = dropContractBalance.etherBalance;
      console.log(
        ethers.utils.formatEther(tokenBalance),
        ethers.utils.formatEther(nftBalance),
        ethers.utils.formatEther(etherBalance)
      );
      expect(tokenBalance, "Token balance check").to.equal(tokenAmount);
      expect(nftBalance, "Token balance check").to.equal(tokenIDs.length);
      expect(etherBalance, "Ether balance check").to.equal(etherAmount);
      // 가스피 수신자 잔액 체크
      const txFeeReceiverBalance = await ethers.provider.getBalance(
        txFeeReceiver.address
      );
      console.log(
        "txFeeReceiverBalance",
        ethers.utils.formatEther(txFeeReceiverBalance.toString())
      );
      // 유료비용 수신자 잔액 체크
      const CostReceiverBalance = await ethers.provider.getBalance(
        costReceiver.address
      );
      console.log(
        "CostReceiverBalance",
        ethers.utils.formatEther(CostReceiverBalance.toString())
      );
    });
  });

  describe("4. Airdrop", () => {
    // 링크 가져오기
    it("Get airdrop links", async () => {
      const numberOfLinks = await proxiedERCImpleInstance.numberOfLinks();
      console.log("numberOfLinks>>>>>>>>>", numberOfLinks.toString());
      const links = await proxiedERCImpleInstance.connect(client).getLinks();
      airdropLinks = await links.map((link) => {
        return {
          linkIndex: link.id.toString(),
          tokenBalance: link.tokenBalance.toString(),
          etherBalance: link.etherBalance.toString(),
          tokenID: link.tokenID.toString(),
          puzzle: link.puzzle,
        };
      });
      console.log("links", airdropLinks);
      expect(airdropLinks.length, "Check link count").to.equal(numberOfLinks);
    });

    //에어드랍1;
    it("Run airdrop ", async () => {
      const airdropParam = airdropLinks[0];
      const linkID = airdropParam.linkIndex;
      const tokenBalance = airdropParam.tokenBalance;
      const etherBalance = airdropParam.etherBalance;
      const tokenID = airdropParam.tokenID;
      const puzzle = airdropParam.puzzle;
      // todo: add claimer signature

      const beforeClaimer1Balance = await ethers.provider.getBalance(
        claimer1.address
      );

      const airdropTx = await proxiedERCImpleInstance
        .connect(campaignEOA)
        .airdrop(
          linkID,
          tokenBalance,
          etherBalance,
          tokenID,
          puzzle,
          claimer1.address,
          {
            gasLimit: 700000,
          }
        );
      await airdropTx.wait();
      const links = await proxiedERCImpleInstance.connect(client).getLinks();
      const afterAirdropLinks = await links.map((link) => {
        return {
          linkIndex: link.id.toString(),
          tokenBalance: link.tokenBalance.toString(),
          etherBalance: link.etherBalance.toString(),
          tokenID: link.tokenID.toString(),
          puzzle: link.puzzle,
          wallet: link.wallet,
        };
      });
      console.log("afterAirdropLinks[0]", afterAirdropLinks[0]);
      expect(afterAirdropLinks[0].wallet, "Check link claimer").to.equal(
        claimer1.address
      );
      expect(
        afterAirdropLinks[0].etherBalance,
        "Check link ether balance"
      ).to.equal("0");

      const claimer1TokenBalance = await TokenInstance.balanceOf(
        claimer1.address
      );
      expect(claimer1TokenBalance, "Check claimer Token balance").to.equal(1);

      const nft0Owner = await TokenInstance.ownerOf(
        afterAirdropLinks[0].tokenID
      );
      expect(nft0Owner, "Check owner").to.equal(claimer1.address);

      const afterClaimer1Balance = await ethers.provider.getBalance(
        claimer1.address
      );
      console.log("claimer1.address", claimer1.address);
      console.log(
        "claimer1TokenBalance",
        ethers.utils.formatEther(claimer1TokenBalance)
      );
      console.log(
        "beforeClaimer1Balance",
        ethers.utils.formatEther(beforeClaimer1Balance)
      );
      console.log(
        "afterClaimer1Balance",
        ethers.utils.formatEther(afterClaimer1Balance)
      );
      expect(
        afterClaimer1Balance.sub(beforeClaimer1Balance),
        "Check claimer1 ether balance increase"
      ).to.be.closeTo(etherBalance, ethers.utils.parseUnits("0.0001", 18));

      expect(
        afterClaimer1Balance,
        "Check claimer1 ether balance"
      ).to.be.greaterThan(etherBalance);
    });
  });

  describe("5. Pause or Run toggle test", async () => {
    it("Pause and run Campaign", async () => {
      await proxiedERCImpleInstance.connect(client).toggleRunOrPause();
      const statePaused = await proxiedERCImpleInstance.campaignState();
      console.log("statePaused", statePaused);
      expect(statePaused, "Check campaign state").to.equal(2);

      await proxiedERCImpleInstance.connect(client).toggleRunOrPause();
      const stateRunning = await proxiedERCImpleInstance.campaignState();

      console.log("stateRunning", stateRunning);

      expect(stateRunning, "Check campaign state").to.equal(1);
    });

    it("Cancel Campaign", async () => {
      // 캔슬전 클라이언트 token 보유수량
      const clientTokenBalanceBefore = await TokenInstance.balanceOf(
        client.address
      );
      // 캔슬전 클라이언트 이더 잔액
      const clientEtherBalanceBefore = await ethers.provider.getBalance(
        client.address
      );
      // 캔슬전 컨트랙트 잔액
      const contractBalanceBefore = await proxiedERCImpleInstance
        .connect(client)
        .getBalance();
      const contractNumberOfLinks = await proxiedERCImpleInstance
        .connect(client)
        .numberOfLinks();
      console.log("contractNumberOfLinks", contractNumberOfLinks);
      await proxiedERCImpleInstance.connect(client).cancelCampaign();
      // 캔슬후 클라이언트 token 보유수량
      const clientTokenBalanceAfter = await TokenInstance.balanceOf(
        client.address
      );
      // 캔슬후 클라이언트 이더 잔액
      const clientEtherBalanceAfter = await ethers.provider.getBalance(
        client.address
      );
      // 캔슬후 컨트랙트 잔액
      const contractBalanceAfter = await proxiedERCImpleInstance
        .connect(client)
        .getBalance();
      console.log(
        "before client Token balance:",
        ethers.utils.formatEther(clientTokenBalanceBefore)
      );
      console.log(
        "after client Token balance:",
        ethers.utils.formatEther(clientTokenBalanceAfter)
      );
      console.log(
        "before client Ether balance:",
        ethers.utils.formatEther(clientEtherBalanceBefore)
      );
      console.log(
        "after client Ether balance:",
        ethers.utils.formatEther(clientEtherBalanceAfter)
      );
      console.log(
        "before contract balance:",
        ethers.utils.formatEther(contractBalanceBefore[0]),
        ethers.utils.formatEther(contractBalanceBefore[1]),
        contractBalanceBefore[2].toString()
      );
      console.log(
        "after contract balance:",
        ethers.utils.formatEther(contractBalanceAfter[0]),
        ethers.utils.formatEther(contractBalanceAfter[1]),
        contractBalanceAfter[2].toString()
      );

      console.log("!!!!!!", clientTokenBalanceBefore.toString());
      console.log("!!!!!!", clientTokenBalanceAfter.toString());
      expect(
        clientTokenBalanceAfter,
        "Check client token balance increase"
      ).to.equal(clientTokenBalanceBefore.add(tokenIDs.length - 1));
      expect(
        clientEtherBalanceAfter,
        "Check client ether balance increase"
      ).to.be.greaterThan(clientEtherBalanceBefore);
      expect(
        contractBalanceAfter.tokenBalance,
        "Check contract token balance"
      ).to.equal(0);
      expect(
        contractBalanceAfter.etherBalance,
        "Check contract ether balance"
      ).to.equal(0);
      expect(
        contractBalanceAfter.nftBalance,
        "Check contract ether balance"
      ).to.equal(0);
    });
  });
}); // end of main describe
