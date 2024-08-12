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
echo "##### Start explorer db #########"
echo ""

# Starting hyperledger fabricchannel
#docker-compose -f docker-compose.yml up -d  \
#explorerdb.test.hu

sleep 20

echo ""
echo "##### Start explorer #########"
echo ""

# Starting hyperledger fabricchannel
#docker-compose -f docker-compose.yml up -d  \
#explorer.test.hu

echo ""
echo "##### Start prometheus #########"
echo ""

# Starting prometheus
#docker-compose -f docker-compose.yml up -d  \
#prometheus.test.hu

echo ""
echo "##### Modify on-chain config #########"
echo ""

# https://medium.com/coinmonks/modifying-the-batch-size-in-hyperledger-fabric-v2-2-3ec2dd779e2b

# fetch config
docker exec cli.org1.test.hu \
peer channel fetch config config_block.pb \
-o orderer.test.hu:7050 -c testchannel \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem

# convert to json
docker exec cli.org1.test.hu \
sh -c 'configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json'

MAXBATCHSIZEPATH=".channel_group.groups.Orderer.values.BatchSize.value.max_message_count"

# check value
docker exec -e MAXBATCHSIZEPATH=$MAXBATCHSIZEPATH cli.org1.test.hu \
sh -c 'jq "$MAXBATCHSIZEPATH" config.json'

# update value
docker exec -e MAXBATCHSIZEPATH=$MAXBATCHSIZEPATH cli.org1.test.hu \
sh -c 'jq "$MAXBATCHSIZEPATH = 20" config.json > modified_config.json'

# convert to protobuf
docker exec cli.org1.test.hu sh -c 'configtxlator proto_encode --input config.json --type common.Config --output config.pb'

docker exec cli.org1.test.hu sh -c 'configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb'

# data calculation
docker exec -e CHANNEL_NAME=testchannel cli.org1.test.hu sh -c 'configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output final_update.pb'

# add update to envelop
docker exec cli.org1.test.hu sh -c 'configtxlator proto_decode --input final_update.pb --type common.ConfigUpdate | jq . > final_update.json'
docker exec cli.org1.test.hu sh -c 'echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"testchannel\", \"type\":2}},\"data\":{\"config_update\":"$(cat final_update.json)"}}}" | jq . >  header_in_envolope.json'
docker exec cli.org1.test.hu sh -c 'configtxlator proto_encode --input header_in_envolope.json --type common.Envelope --output final_update_in_envelope.pb'

# sign
docker exec cli.org1.test.hu sh -c 'peer channel signconfigtx -f final_update_in_envelope.pb'

# send update

CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/test.hu/orderers/orderer.test.hu/tls/ca.crt
CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/test.hu/users/Admin@test.hu/msp
CORE_PEER_ADDRESS=orderer.test.hu:7050

docker exec \
-e CORE_PEER_LOCALMSPID=OrdererMSP \
-e CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE} \
-e CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH \
-e CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
cli.org1.test.hu sh \
-c 'peer channel update -f final_update_in_envelope.pb -c testchannel -o orderer.test.hu:7050 --tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem' 

echo ""
echo "##### Test enroll certs #########"
echo ""

ACTUALDIR=$(dirname $(readlink -f $0))
echo "actual directory: ${ACTUALDIR}"

# create test directory structure
mkdir -p ${ACTUALDIR}/testcerts
mkdir -p ${ACTUALDIR}/testcerts/testcert
mkdir -p ${ACTUALDIR}/testcerts/peer
mkdir -p ${ACTUALDIR}/testcerts/peer/sign
mkdir -p ${ACTUALDIR}/testcerts/peer/sign2
mkdir -p ${ACTUALDIR}/testcerts/peer/tls
mkdir -p ${ACTUALDIR}/testcerts/peer/tls2
mkdir -p ${ACTUALDIR}/testcerts/peer/admin
mkdir -p ${ACTUALDIR}/testcerts/peer/admintls
mkdir -p ${ACTUALDIR}/testcerts/peer/admin2
mkdir -p ${ACTUALDIR}/testcerts/peer/admintls2

export FABRIC_CA_CLIENT_TLS_CERTFILES=${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem
export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcerts/testcert

# enroll admin testcert
fabric-ca-client enroll -d -u http://test:Blockchain4ever@ca.org1.test.hu:7054 --tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem 

fabric-ca-client register -d --id.name Admin@org1.test.hu --id.secret xxx \
--id.type admin --csr.names "C=HU,ST=Budapest,L=Budapest,O=org1.test.hu,OU=org1MSP" \
--id.attrs hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true” -u http://ca.org1.test.hu:7054 --tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

fabric-ca-client enroll -d -u http://Admin@org1.test.hu:xxx@ca.org1.test.hu:7054 --csr.names "C=HU,ST=Budapest,L=Budapest,O=org1.test.hu,OU=og1MSP" --csr.hosts peer1.org1.test.hu --mspdir ./testcerts/testcert --tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

##########
## PEER ##
##########

### Peer register ###

# register peer identity for the organization
fabric-ca-client register -d --id.name peer0-org1 --id.secret peer0PW \
--id.type peer \
--id.attrs '"hf.Registrar.Roles=peer"' \
--csr.cn "peer0.org1.test.hu" \
--csr.hosts "peer0.org1.test.hu" --csr.names "C=HU,ST=Budapest,L=Budapest,O=org1.test.hu,OU=org1MSP" \
--id.affiliation "org1" \
-u http://ca.org1.test.hu:7054 --tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

# Peer signcert

export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcerts/peer/sign

# enroll peer signcert for the organization
fabric-ca-client enroll -d -u http://peer0-org1:peer0PW@ca.org1.test.hu:7054 \
--csr.hosts peer0.org1.test.hu \
--csr.names "C=HU,ST=Budapest,L=Budapest,O=org1.test.hu,OU=org1MSP" \
--mspdir ${ACTUALDIR}/testcerts/peer/sign \
--tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

# Peer TLS
export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcerts/peer/tls

# enroll peer TLS cert for the organization
fabric-ca-client enroll -d -u http://peer0-org1:peer0PW@ca.org1.test.hu:7054 \
--enrollment.profile tls --csr.hosts peer0.org1.test.hu \
--mspdir ${ACTUALDIR}/testcerts/peer/tls \
--tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

sleep 60

export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcerts/peer/sign2

# reenroll peer identity for the organization
fabric-ca-client enroll -d -u http://peer0-org1:peer0PW@ca.org1.test.hu:7054 \
--csr.hosts peer0.org1.test.hu \
--csr.names "C=HU,ST=Budapest,L=Budapest,O=org1.test.hu,OU=org1MSP" \
--mspdir ${ACTUALDIR}/testcerts/peer/sign2 \
--tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcerts/peer/tls2

# reenroll peer TLS cert for the organization
fabric-ca-client enroll -d -u http://peer0-org1:peer0PW@ca.org1.test.hu:7054 \
--enrollment.profile tls --csr.hosts peer0.org1.test.hu \
--mspdir ${ACTUALDIR}/testcerts/peer/tls2 \
--tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

##########
## ORG1 admin ##
##########

export FABRIC_CA_CLIENT_TLS_CERTFILES=${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem
export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcerts/testcert

fabric-ca-client enroll -d -u http://test:Blockchain4ever@ca.org1.test.hu:7054 --tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem 

# register Org admin - Org1
fabric-ca-client register -d --id.name Admin2@org1.test.hu --id.secret orgadminPW \
--id.type admin --csr.names "C=HU,ST=Budapest,L=Budapest,O=org1.test.hu,OU=org1MSP" \
--id.attrs hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true” \
-u http://ca.org1.test.hu:7054 \
--tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcerts/peer/admin

# enroll org admin
fabric-ca-client enroll -d -u http://Admin2@org1.test.hu:orgadminPW@ca.org1.test.hu:7054 \
--csr.names "C=HU,ST=Budapest,L=Budapest,O=org1.test.hu,OU=org1MSP" \
--mspdir ${ACTUALDIR}/testcerts/peer/admin \
--tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcerts/peer/admintls

# enroll Org1 - Admin - TLS
fabric-ca-client enroll -d -u http://Admin2@org1.test.hu:orgadminPW@ca.org1.test.hu:7054 \
--enrollment.profile tls --csr.hosts "org1.test.hu" \
--mspdir ${ACTUALDIR}/testcerts/peer/admintls \
--tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

sleep 60

export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcerts/peer/admin2

# reenroll org admin
fabric-ca-client enroll -d -u http://Admin2@org1.test.hu:orgadminPW@ca.org1.test.hu:7054 \
--csr.names "C=HU,ST=Budapest,L=Budapest,O=org1.test.hu,OU=org1MSP" \
--mspdir ${ACTUALDIR}/testcerts/peer/admin2 \
--tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem

export FABRIC_CA_CLIENT_HOME=${ACTUALDIR}/testcerts/peer/admintls2

# reenroll Org1 - Admin - TLS
fabric-ca-client enroll -d -u http://Admin2@org1.test.hu:orgadminPW@ca.org1.test.hu:7054 \
--enrollment.profile tls --csr.hosts "org1.test.hu" \
--mspdir ${ACTUALDIR}/testcerts/peer/admintls2 \
--tls.certfiles ${ACTUALDIR}/crypto-config/peerOrganizations/org1.test.hu/tlsca/tlsca.org1.test.hu-cert.pem


echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0

