/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

const grpc = require("@grpc/grpc-js");
const crypto = require("node:crypto");
const { connect, signers } = require("@hyperledger/fabric-gateway");
const fs = require("node:fs");
const util = require("node:util");

const utf8Decoder = new util.TextDecoder()

async function main() {
  const appUser = JSON.parse(fs.readFileSync('wallet/admin.id'));
  credentials = Buffer.from(appUser.credentials.certificate);
  const identity = { mspId: "Org1MSP", credentials };

  const privateKeyPem = Buffer.from(appUser.credentials.privateKey);
  const privateKey = crypto.createPrivateKey(privateKeyPem);
  const signer = signers.newPrivateKeySigner(privateKey);

  const tlsRootCert = fs.readFileSync("/home/dsz/git/fabrictraining/crypto-config/peerOrganizations/org1.test.hu/peers/peer0.org1.test.hu/tls/ca.crt");
  const client = new grpc.Client(
    "peer0.org1.test.hu:7051",
    grpc.credentials.createSsl(tlsRootCert)
  )

  const gateway = connect({ identity, signer, client });
  try {
    const network = gateway.getNetwork("testchannel");
    const contract = network.getContract("test");

    const getResult = await contract.evaluateTransaction("GetState");
    console.log("Get result:", utf8Decoder.decode(getResult))
  } finally {
    gateway.close()
    client.close()
  }
}

main().catch(console.error)
