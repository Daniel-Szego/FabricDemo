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
echo "##### UPGRADE #########"
echo "##########################################################"

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
echo "##### test Dev network is starting #########"
echo "##########################################################"


# Shutting down exisiting network
docker-compose -f docker-compose.yml down

sleep 40

# rebuild dal container

#cd dalnew

#docker build -t dal:01 .

#cd ..

#sleep 20

# Starting hyperledger fabricchannel
docker-compose -f docker-compose-new.yml up -d  \
ca.org1.test.hu \
orderer.test.hu \
orderer1.test.hu \
orderer2.test.hu \
peer0.org1.test.hu \
couchdb0.org1.test.hu \
cli.org1.test.hu

# wait for Hyperledger Fabric to start
# incase of errors when running later commands, issue export FABRIC_START_TIMEOUT=<larger number>
export FABRIC_START_TIMEOUT=60
#echo ${FABRIC_START_TIMEOUT}
sleep ${FABRIC_START_TIMEOUT}


###################
# DELETE SYS CHANNEL
###################

export OSN_TLS_CA_ROOT_CERT=./crypto-config/ordererOrganizations/test.hu/orderers/orderer.test.hu/tls/ca.crt
export OSN_TLS_CA_ROOT_CERT1=./crypto-config/ordererOrganizations/test.hu/orderers/orderer1.test.hu/tls/ca.crt
export OSN_TLS_CA_ROOT_CERT2=./crypto-config/ordererOrganizations/test.hu/orderers/orderer2.test.hu/tls/ca.crt
export OSN_TLS_CA_ROOT_CERT3=./crypto-config/ordererOrganizations/test.hu/orderers/orderer3.test.hu/tls/ca.crt
export OSN_TLS_CA_ROOT_CERT4=./crypto-config/ordererOrganizations/test.hu/orderers/orderer4.test.hu/tls/ca.crt

export ADMIN_TLS_SIGN_CERT=./crypto-config/ordererOrganizations/test.hu/users/Admin@test.hu/tls/client.crt
export ADMIN_TLS_PRIVATE_KEY=./crypto-config/ordererOrganizations/test.hu/users/Admin@test.hu/tls/client.key

# orderer

# list channels
 osnadmin channel list -o orderer.test.hu:9443 --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY

# remove sys-channel
 osnadmin channel remove -o orderer.test.hu:9443 --channelID sys-channel --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY

# list channels
 osnadmin channel list -o orderer.test.hu:9443 --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY

# orderer1

# list channels
 osnadmin channel list -o orderer1.test.hu:9453 --ca-file $OSN_TLS_CA_ROOT_CERT1 --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY

# remove sys-channel
 osnadmin channel remove -o orderer1.test.hu:9453 --channelID sys-channel --ca-file $OSN_TLS_CA_ROOT_CERT1 --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY

# list channels
 osnadmin channel list -o orderer1.test.hu:9453 --ca-file $OSN_TLS_CA_ROOT_CERT1 --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY

# orderer2

# list channels
 osnadmin channel list -o orderer2.test.hu:9463 --ca-file $OSN_TLS_CA_ROOT_CERT2 --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY

# remove sys-channel
 osnadmin channel remove -o orderer2.test.hu:9463 --channelID sys-channel --ca-file $OSN_TLS_CA_ROOT_CERT2 --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY

# list channels
 osnadmin channel list -o orderer2.test.hu:9463 --ca-file $OSN_TLS_CA_ROOT_CERT2 --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY

sleep 20

# restart orderers
docker restart orderer.test.hu
docker restart orderer1.test.hu
docker restart orderer2.test.hu

sleep 20

##########################
# UPGRADE APP CHANNEL
##########################

# link: https://hyperledger-fabric.readthedocs.io/en/release-2.5/updating_capabilities.html

# fecth channel config
docker exec cli.org1.test.hu \
peer channel fetch config blockFetchedConfig.pb \
-o orderer.test.hu:7050 -c testchannel \
--tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem

# decode config
docker exec -it cli.org1.test.hu sh -c \
"configtxlator proto_decode --input blockFetchedConfig.pb \
--type common.Block > config_block.json"

# scope out metadata
docker exec -it cli.org1.test.hu sh -c \
"jq '.data.data[0].payload.data.config' config_block.json > config.json"

# copy to modified 
docker exec -it cli.org1.test.hu sh -c \
"cp config.json modified_config.json"

# ... modify 
docker exec -it cli.org1.test.hu sh -c \
"jq -s '.[0] * {'channel_group':{'groups':{'Application': {'values': {'Capabilities': .[1].application}}}}}' config.json /configfiles/capabilities.json > modified_config.json"

# ... resubmit
docker exec -it cli.org1.test.hu sh -c \
"configtxlator proto_encode --input config.json --type common.Config --output config.pb"

docker exec -it cli.org1.test.hu sh -c \
"configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb"

docker exec -it cli.org1.test.hu sh -c \
"configtxlator compute_update --channel_id testchannel --original config.pb --updated modified_config.pb --output config_update.pb"

docker exec -it cli.org1.test.hu sh -c \
"configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json"

# add header

docker exec -it cli.org1.test.hu sh -c \
"/configfiles/addheader.sh"

docker exec -it cli.org1.test.hu sh -c \
"configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb"


docker exec cli.org1.test.hu \
peer channel signconfigtx -f config_update_in_envelope.pb

CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/test.hu/orderers/orderer.test.hu/tls/ca.crt
CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/test.hu/users/Admin@test.hu/msp
CORE_PEER_ADDRESS=orderer.test.hu:7050

docker exec \
-e CORE_PEER_LOCALMSPID=OrdererMSP \
-e CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE} \
-e CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH \
-e CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
cli.org1.test.hu sh \
-c "peer channel update -f config_update_in_envelope.pb -c testchannel -o orderer.test.hu:7050 --tls --cafile /etc/hyperledger/crypto/orderer/msp/tlscacerts/tlsca.test.hu-cert.pem"

sleep 20

# restart orderers
docker restart orderer.test.hu
docker restart orderer1.test.hu
docker restart orderer2.test.hu

sleep 20

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0
