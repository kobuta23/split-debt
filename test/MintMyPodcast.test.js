const { constants, expectRevert } = require('@openzeppelin/test-helpers');
const { expect } = require("chai")
const { ethers } = require("hardhat")
const { time, mine } = require("@nomicfoundation/hardhat-network-helpers");

// Test Accounts
let owner
let alice
let bob
let eric
let sunny
let joel
let nft

const thousandEther = ethers.utils.parseEther("10000")

before(async function () {

    // get hardhat accounts
    [owner, alice, bob, eric, sunny, joel] = await ethers.getSigners()

})

describe("NFT Contract", function () {

    beforeEach(async () => {

        // deploy nft contract from MintMyPodcast.sol
        const NFT = await ethers.getContractFactory("MintMyPodcast");
        // deploy nft from the contract with all three address parameters set to owner
        nft = await NFT.connect(owner).deploy(
            owner.address,
            owner.address,
            owner.address
        );
        await nft.deployed()
        
        expect(nft.address).to.not.equal(constants.ZERO_ADDRESS)
        // expect nft metadata for token 1 to be empty
        expect(await nft.tokenURI(1)).to.equal("")

        console.log("NFT deployed to:", nft.address);
    })

    afterEach(async () => {
        // transfer out all funds
        // check the address has no ETH left

    });

    it("can't mint if no metadata set", async function () {
        // Alice tries to mint an NFT without metadata set
        // expect revert
        expectRevert(nft.connect(alice).mint(alice.address), "MintMyPodcast: Metadata not set yet");
    });

    it("minter is the only one who can set metadata", async function () {
        // Alice tries to set metadata
        // expect revert
        expectRevert(nft.connect(alice).setMetadata("https://mintmypodcast.com/metadata/"), "MintMyPodcast: Only minter can set metadata");
    });

    it("metadata can be set properly", async function () {
        // owner can set metadata and it is set properly
        await nft.connect(owner).setMetadata(1,"https://mintmypodcast.com/metadata/");
        expect(await nft.tokenURI(10001)).to.equal("https://mintmypodcast.com/metadata/");
    });

    it("metadata can be updated by setter", async function () {
        // owner can set metadata and it is set properly
        await nft.connect(owner).setMetadata(1,"https://mintmypodcast.com/metadata/");
        expect(await nft.tokenURI(10001)).to.equal("https://mintmypodcast.com/metadata/");
        // setter can update metadata
        await nft.connect(owner).setMetadata(1,"https://mintmypodcast.com/metadata/2/");
        expect(await nft.tokenURI(10001)).to.equal("https://mintmypodcast.com/metadata/2/");

    });

    it("anyone can mint for free", async function () {
        // owner can set metadata and it is set properly
        await nft.connect(owner).setMetadata(1,"https://mintmypodcast.com/metadata/");
        expect(await nft.tokenURI(10001)).to.equal("https://mintmypodcast.com/metadata/");
        // anyone can mint for free
        await nft.connect(alice).mint(1);
        expect(await nft.balanceOf(alice.address)).to.equal(1);
        // check with two more users
        await nft.connect(bob).mint(1);
        expect(await nft.balanceOf(bob.address)).to.equal(1);
        await nft.connect(eric).mint(1);
        expect(await nft.balanceOf(eric.address)).to.equal(1);
    });

    it.skip("only allows minting up to 10000", async function () {
        // owner can set metadata and it is set properly
        await nft.connect(owner).setMetadata(1,"https://mintmypodcast.com/metadata/");
        expect(await nft.tokenURI(10001)).to.equal("https://mintmypodcast.com/metadata/");
        // anyone can mint for free
        // loop 10000 times
        for (let i = 0; i < 10000; i++) {
            await nft.connect(alice).mint(1);
        }
        expect(await nft.balanceOf(alice.address)).to.equal(10000);
        // expect revert
        expectRevert(nft.connect(eric).mint(1), "MintMyPodcast: Maximum 10'000 mints");
    })

    it("token ids are set properly", async function () {
        // owner can set metadata and it is set properly
        await nft.connect(owner).setMetadata(1,"https://mintmypodcast.com/metadata/");
        await nft.connect(owner).setMetadata(2,"https://mintmypodcast.com/metadata/2/");
        await nft.connect(owner).setMetadata(3,"https://mintmypodcast.com/metadata/3/");
        await nft.connect(owner).setMetadata(4,"https://mintmypodcast.com/metadata/4/");
        await nft.connect(owner).setMetadata(5,"https://mintmypodcast.com/metadata/5/");
        // check all metadata set correctly
        expect(await nft.tokenURI(10001)).to.equal("https://mintmypodcast.com/metadata/");
        expect(await nft.tokenURI(20001)).to.equal("https://mintmypodcast.com/metadata/2/");
        expect(await nft.tokenURI(30001)).to.equal("https://mintmypodcast.com/metadata/3/");
        expect(await nft.tokenURI(40001)).to.equal("https://mintmypodcast.com/metadata/4/");
        expect(await nft.tokenURI(50001)).to.equal("https://mintmypodcast.com/metadata/5/");
        
        // mint 5 tokens
        for (let i = 1; i < 6; i++) {
            await nft.connect(alice).mint(i);
        }
        // check token ids
        for (let i = 1; i < 6; i++) {
            // expect ownerOf token id to be alice
            console.log("got this far", i*10000+1)
            expect(await nft.ownerOf(i*10000+1)).to.equal(alice.address);
        }
    });

    it("pricing function works properly", async function () {
        // set metadata for one token
        await nft.connect(owner).setMetadata(1,"https://mintmypodcast.com/metadata/");
        
        // ALICE MInts for free
        await nft.connect(alice).mint(1);
        expect(await nft.balanceOf(alice.address)).to.equal(1);
        // alice mints again, sends 0.1 ETH
        await nft.connect(alice).mint(1, {value: ethers.utils.parseEther("0.1")});
        expect(await nft.balanceOf(alice.address)).to.equal(2);
        // alice mints again, sends 0.1 ETH expect revert
        await expectRevert(nft.connect(alice).mint(1, {value: ethers.utils.parseEther("0.1")}), "MintMyPodcast: Not enough ETH sent");
        // alice mints again, sends 0.2 ETH
        await nft.connect(alice).mint(1, {value: ethers.utils.parseEther("0.2")});
        expect(await nft.balanceOf(alice.address)).to.equal(3);
    });

    it("maximum 10'000 mints", async function () {


    });

    it("", async function () {


    });
});