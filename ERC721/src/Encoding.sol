// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract Encoding {
    function combineStrings() public pure returns (string memory) {
        return string(abi.encodePacked("Hi Mom! ", "Miss You"));
    }

    function encodeNumber() public pure returns (bytes memory) {
        bytes memory number = abi.encode(1);
        return number;
    }

    function encodeString() public pure returns (bytes memory) {
        bytes memory someString = abi.encode("some string");
        return someString;
    }

    function encodeStringPacked() public pure returns (bytes memory) {
        bytes memory someString = abi.encodePacked("some string");
        return someString;
    }

    function encodeStringWithBytes() public pure returns (bytes memory) {
        bytes memory someBytes = bytes("some string");
        return someBytes;
    } 

    function decodeString() public pure returns (string memory) {
        string memory someDecodedData = abi.decode(encodeString(), (string));
        return someDecodedData;
    }

    function multiEncode() public pure returns (bytes memory) {
        bytes memory someString = abi.encode("some string", "It's bigger");
        return someString;
    }

    function multiDecode() public pure returns (string memory, string memory) {
        (string memory someString, string memory someOtherString) = abi.decode(multiEncode(), (string, string));
        return (someString, someOtherString);
    }

    function multiEncodePacked() public pure returns (bytes memory) {
        bytes memory someString = abi.encodePacked("some string", "It's bigger");
        return someString;
    }

    //This doesn't work!
    function multiDecodePacked() public pure returns (string memory, string memory) {
        (string memory someString, string memory someOtherString) = abi.decode(multiEncodePacked(), (string, string));
        return (someString, someOtherString);
    }

    //This works btw for encodePacked
    function multiStringCastPacked() public pure returns (string memory) {
        string memory someString = string(multiEncodePacked());
        return someString;
    }

    // ABI
    // contrcat Address 
    // Neded to populate the data field in the txn
    // using staticcall and call
    // Call: How we call functions to change the state of the blockchain
    // staticCall: This is how (as a low level) we do our "view" or "pure" function calls, and potentially do not change the blockchain
}