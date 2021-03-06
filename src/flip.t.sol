pragma solidity ^0.4.20;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "./flip.sol";

contract Guy {
    Flipper flip;
    function Guy(Flipper flip_) public {
        flip = flip_;
        DSToken(flip.pie()).approve(flip);
    }
    function tend(uint id, uint lot, uint bid) public {
        flip.tend(id, lot, bid);
    }
    function dent(uint id, uint lot, uint bid) public {
        flip.dent(id, lot, bid);
    }
    function deal(uint id) public {
        flip.deal(id);
    }
    function try_tend(uint id, uint lot, uint bid)
        public returns (bool)
    {
        bytes4 sig = bytes4(keccak256("tend(uint256,uint256,uint256)"));
        return flip.call(sig, id, lot, bid);
    }
    function try_dent(uint id, uint lot, uint bid)
        public returns (bool)
    {
        bytes4 sig = bytes4(keccak256("dent(uint256,uint256,uint256)"));
        return flip.call(sig, id, lot, bid);
    }
    function try_deal(uint id)
        public returns (bool)
    {
        bytes4 sig = bytes4(keccak256("deal(uint256)"));
        return flip.call(sig, id);
    }
}

contract Vat is VatLike {
    DSToken public gem;
    mapping (address => uint) public lads;
    function Vat(DSToken gem_) public {
        gem = gem_;
    }
    function bump(bytes32 ilk, address lad, uint jam) public {
        gem.pull(msg.sender, jam);
        lads[lad] = jam;
        ilk;
    }
}

contract Gal {}

contract WarpFlip is Flipper {
    uint48 _era; function warp(uint48 era_) public { _era = era_; }
    function era() internal view returns (uint48) { return _era; }
    function WarpFlip(address vat_, bytes32 ilk_, address pie_, address gem_) public
        Flipper(vat_, ilk_, pie_, gem_) {}
}

contract FlipTest is DSTest {
    WarpFlip flip;
    DSToken pie;
    DSToken gem;

    Guy  ali;
    Guy  bob;
    Gal  gal;
    Vat  vat;

    function setUp() public {
        pie = new DSToken('pie');
        gem = new DSToken('gem');

        vat = new Vat(gem);
        flip = new WarpFlip(vat, 'fake ilk', pie, gem);

        flip.warp(1 hours);

        ali = new Guy(flip);
        bob = new Guy(flip);
        gal = new Gal();

        pie.approve(flip);
        gem.approve(flip);

        pie.mint(1000 ether);
        gem.mint(1000 ether);

        pie.push(ali, 200 ether);
        pie.push(bob, 200 ether);
    }
    function test_kick() public {
        flip.kick({ lot: 100 ether
                  , tab: 50 ether
                  , lad: address(0xacab)
                  , gal: gal
                  , bid: 0
                  });
    }
    function testFail_tend_empty() public {
        // can't tend on non-existent
        flip.tend(42, 0, 0);
    }
    function test_tend() public {
        uint id = flip.kick({ lot: 100 ether
                            , tab: 50 ether
                            , lad: address(0xacab)
                            , gal: gal
                            , bid: 0
                            });
        // lot taken from creator
        assertEq(gem.balanceOf(this), 900 ether);

        ali.tend(id, 100 ether, 1 ether);
        // bid taken from bidder
        assertEq(pie.balanceOf(ali), 199 ether);
        // gal receives payment
        assertEq(pie.balanceOf(gal),   1 ether);

        bob.tend(id, 100 ether, 2 ether);
        // bid taken from bidder
        assertEq(pie.balanceOf(bob), 198 ether);
        // prev bidder refunded
        assertEq(pie.balanceOf(ali), 200 ether);
        // gal receives excess
        assertEq(pie.balanceOf(gal),   2 ether);

        flip.warp(5 hours);
        bob.deal(id);
        // bob gets the winnings
        assertEq(gem.balanceOf(flip),  0 ether);
        assertEq(gem.balanceOf(bob), 100 ether);
    }
    function test_tend_later() public {
        uint id = flip.kick({ lot: 100 ether
                            , tab: 50 ether
                            , lad: address(0xacab)
                            , gal: gal
                            , bid: 0
                            });
        // lot taken from creator
        assertEq(gem.balanceOf(this), 900 ether);

        flip.warp(5 hours);

        ali.tend(id, 100 ether, 1 ether);
        // bid taken from bidder
        assertEq(pie.balanceOf(ali), 199 ether);
        // gal receives payment
        assertEq(pie.balanceOf(gal),   1 ether);
    }
    function test_dent() public {
        uint id = flip.kick({ lot: 100 ether
                            , tab: 50 ether
                            , lad: address(0xacab)
                            , gal: gal
                            , bid: 0
                            });
        ali.tend(id, 100 ether,  1 ether);
        bob.tend(id, 100 ether, 50 ether);

        ali.dent(id,  95 ether, 50 ether);
        // plop the gems
        assertEq(gem.balanceOf(flip),  95 ether);
        assertEq(gem.balanceOf(vat),    5 ether);
        assertEq(pie.balanceOf(ali),  150 ether);
        assertEq(pie.balanceOf(bob),  200 ether);
    }
    function test_beg() public {
        uint id = flip.kick({ lot: 100 ether
                            , tab: 50 ether
                            , lad: address(0xacab)
                            , gal: gal
                            , bid: 0
                            });
        assertTrue( ali.try_tend(id, 100 ether, 1.00 ether));
        assertTrue(!bob.try_tend(id, 100 ether, 1.01 ether));
        // high bidder isn't subject to beg
        assertTrue( ali.try_tend(id, 100 ether, 1.01 ether));
        assertTrue( bob.try_tend(id, 100 ether, 1.07 ether));

        // can bid by less than beg at flip
        assertTrue( ali.try_tend(id, 100 ether, 49 ether));
        assertTrue( bob.try_tend(id, 100 ether, 50 ether));

        assertTrue(!ali.try_dent(id, 100 ether, 50 ether));
        assertTrue(!ali.try_dent(id,  99 ether, 50 ether));
        assertTrue( ali.try_dent(id,  95 ether, 50 ether));
    }
    function test_deal() public {
        uint id = flip.kick({ lot: 100 ether
                            , tab: 50 ether
                            , lad: address(0xacab)
                            , gal: gal
                            , bid: 0
                            });

        // only after ttl
        ali.tend(id, 100 ether, 1 ether);
        assertTrue(!bob.try_deal(id));
        flip.warp(4.1 hours);
        assertTrue( bob.try_deal(id));

        uint ie = flip.kick({ lot: 100 ether
                            , tab: 50 ether
                            , lad: address(0xacab)
                            , gal: gal
                            , bid: 0
                            });

        // or after end
        flip.warp(1 weeks);
        ali.tend(ie, 100 ether, 1 ether);
        assertTrue(!bob.try_deal(ie));
        flip.warp(1.1 weeks);
        assertTrue( bob.try_deal(ie));
    }
}
