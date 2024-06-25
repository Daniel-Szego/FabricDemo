#!/bin/bash
##
# Exit on first error, print all commands.
set -ev

# don't rewrite paths for Windows Git Bash users
export MSYS_NO_PATHCONV=1

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo

echo "##########################################################"
echo "##### Preparing files #########"
echo "##########################################################"

echo "Chaincode File path:"
echo $1
echo "Client File path:"
echo $2
echo "with explorer"
echo $3

# basic channel name of the application
CHANNEL_NAME=testchannel
# channel block name
CHANNEL_BLOCK=testchannel.block

# This could fail in case of an intermediate symlink
SCRIPT_PATH=$(dirname $0)
CHAINCODE_LOCAL_PATH=${SCRIPT_PATH}/chaincode/test

echo ""
echo "##### Copying chaincode from: '${CHAINCODE_LOCAL_PATH}' to '${SCRIPT_PATH}/chaincode' #########"
echo ""

#cp -r "${CHAINCODE_LOCAL_PATH}" "${SCRIPT_PATH}/chaincode"


echo "##########################################################"
echo "##### Test network is starting #########"
echo "##########################################################"

# Shutting down exisiting network
docker-compose -f docker-compose.yml down

# Starting hyperledger fabricchannel
docker-compose -f docker-compose.yml up -d  \
ca.org1.test.hu \
orderer.test.hu \
orderer1.test.hu \
orderer2.test.hu \
peer0.org1.test.hu \
couchdb0.org1.test.hu \
cli.org1.test.hu \

# wait for Hyperledger Fabric to start
# incase of errors when running later commands, issue export FABRIC_START_TIMEOUT=<larger number>
export FABRIC_START_TIMEOUT=30
#echo ${FABRIC_START_TIMEOUT}
sleep ${FABRIC_START_TIMEOUT}

# Create the channel

echo ""
echo "##### Creating channel : testchannel #########"
echo ""

docker exec \
cli.org1.test.hu peer channel create -o orderer.test.hu:7050 \
-c $CHANNEL_NAME -f /etc/hyperledger/channel/testchannel.tx \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem

echo ""
echo "##### Join channel peer0.org1.test.hu #########"
echo ""

docker exec cli.org1.test.hu \
peer channel \
fetch 0 $CHANNEL_BLOCK -c $CHANNEL_NAME  \
-o orderer.test.hu:7050  \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem

docker exec cli.org1.test.hu  \
peer channel join -b $CHANNEL_BLOCK  \
-o orderer.test.hu:7050  \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem

echo ""
echo "##### List channels  - test #########"
echo ""

docker exec cli.org1.test.hu peer channel list

echo ""
echo "##### Update Anchor peer Org1 #########"
echo ""

docker exec cli.org1.test.hu peer channel update -o orderer.test.hu:7050 \
-c $CHANNEL_NAME -f /etc/hyperledger/channel/testMSPanchors.tx \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem

echo ""
echo "##### Package chaincode #########"
echo ""

docker exec cli.org1.test.hu peer lifecycle chaincode package test.tar.gz \
--path /chaincode/go --label test \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem

echo ""
echo "##### Install chaincode  #########"
echo ""

docker exec cli.org1.test.hu \
peer lifecycle chaincode install test.tar.gz \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem

echo ""
echo "##### Query installed chaincode #########"
echo ""

docker exec cli.org1.test.hu \
peer lifecycle chaincode queryinstalled

echo ""
echo "##### Query installed chaincode #########"
echo ""

package_id=$(docker exec cli.org1.test.hu peer lifecycle chaincode queryinstalled | grep 'Package ID' | sed 's/Package ID:* //' | sed 's/,.*//')

echo ""
echo "##### Approve chaincode  #########"
echo ""

docker exec cli.org1.test.hu \
peer lifecycle chaincode approveformyorg --channelID testchannel --name test --version 1.0 --package-id  ${package_id} --sequence 1 \
-o orderer.test.hu:7050 \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem

echo ""
echo "##### Check commit readiness #########"
echo ""

docker exec cli.org1.test.hu \
peer lifecycle chaincode checkcommitreadiness --channelID testchannel --name test --version 1.0 --sequence 1 \
-o orderer.test.hu:7050 \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem

echo ""
echo "##### Commit chaincode #########"
echo ""

docker exec cli.org1.test.hu \
peer lifecycle chaincode commit \
-o orderer.test.hu:7050 \
--channelID testchannel --name test --version 1.0 --sequence 1 \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem \
--peerAddresses peer0.org1.test.hu:7051 \
--tlsRootCertFiles /etc/hyperledger/crypto/peer/tls/ca.crt \

sleep 20

docker exec cli.org1.test.hu \
peer chaincode invoke \
-o orderer.test.hu:7050 \
--channelID testchannel --name test \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem \
--peerAddresses peer0.org1.test.hu:7051 \
--tlsRootCertFiles /etc/hyperledger/crypto/peer/tls/ca.crt \
-c '{"Args":["InitLedger"]}' --waitForEvent

sleep 20

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0

