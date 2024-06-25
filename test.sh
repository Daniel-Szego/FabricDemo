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
echo "##### Test PutState #########"
echo ""

docker exec cli.org1.test.hu  \
peer chaincode invoke \
 -o orderer.test.hu:7050 \
 -C testchannel -n test  \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem \
--peerAddresses peer0.org1.test.hu:7051 \
--tlsRootCertFiles /etc/hyperledger/crypto/peer/tls/ca.crt \
 -c '{"Args":["PutState","adat123"]}' --waitForEvent

echo ""
echo "##### Test GetState #########"
echo ""

docker exec cli.org1.test.hu  \
peer chaincode query -n test -c '{"Args":["GetState"]}' -C testchannel

echo ""
echo "##### Test PutStateKey #########"
echo ""

docker exec cli.org1.test.hu  \
peer chaincode invoke \
 -o orderer.test.hu:7050 \
 -C testchannel -n test  \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem \
--peerAddresses peer0.org1.test.hu:7051 \
--tlsRootCertFiles /etc/hyperledger/crypto/peer/tls/ca.crt \
 -c '{"Args":["PutStateKey","key123", "adat321"]}' --waitForEvent

echo ""
echo "##### Test GetStateKey #########"
echo ""

docker exec cli.org1.test.hu  \
peer chaincode query -n test -c '{"Args":["GetStateKey","key123"]}' -C testchannel


echo ""
echo "##### Test client #########"
echo ""

cd client

npm install

rm -rf wallet

npm run enrollex

npm run registerex

npm run put

npm run get

npm run putkey

npm run getkey

cd ..

echo ""
echo "##### Test enroll cert #########"
echo ""

ACTUALDIR=$(dirname $(readlink -f $0))
echo "actual directory: ${ACTUALDIR}"

export FABRIC_CA_CLIENT_TLS_CERTFILES=${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem
export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcert/

# enroll admin
fabric-ca-client enroll -d -u http://test:Blockchain4ever@ca.org1.test.hu:7054 --tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem 

fabric-ca-client register -d --id.name Admin@org1.test.hu --id.secret xxx \
--id.type admin --csr.names "C=HU,ST=Budapest,L=Budapest,O=org1.test.hu,OU=org1MSP" \
--id.attrs hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true” -u http://ca.org1.test.hu:7054 --tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

fabric-ca-client enroll -d -u http://Admin@org1.test.hu:xxx@ca.org1.test.hu:7054 --csr.names "C=HU,ST=Budapest,L=Budapest,O=org1.test.hu,OU=og1MSP" --csr.hosts peer1.org1.test.hu --mspdir ./testcert --tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem


echo ""
echo "##### Start explorer db #########"
echo ""

# Starting hyperledger fabricchannel
docker-compose -f docker-compose.yml up -d  \
explorerdb.test.hu

sleep 20

echo ""
echo "##### Start explorer #########"
echo ""

# Starting hyperledger fabricchannel
docker-compose -f docker-compose.yml up -d  \
explorer.test.hu

echo ""
echo "##### Start prometheus #########"
echo ""

# Starting prometheus
docker-compose -f docker-compose.yml up -d  \
prometheus.test.hu

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0

