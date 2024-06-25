/*
SPDX-License-Identifier: Apache-2.0
*/

package main

import (
	"fmt"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct {
	contractapi.Contract
}

// InitLedger adds a base set of cars to the ledger
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	return nil
}


func (s *SmartContract) GetState(ctx contractapi.TransactionContextInterface) (string) {


	dataBytes, err := ctx.GetStub().GetState("idx")

	if err != nil {
		return err.Error()
	}

	myData := string(dataBytes)

    return myData
}


func (s *SmartContract) PutState(ctx contractapi.TransactionContextInterface, data string) (string) {

	err := ctx.GetStub().PutState("idx", []byte(data))
	if err != nil {
		return "error"
	}

	return "success"
}

func (s *SmartContract) GetStateKey(ctx contractapi.TransactionContextInterface, key string) (string) {


	dataBytes, err := ctx.GetStub().GetState(key)

	if err != nil {
		return err.Error()
	}

	myData := string(dataBytes)

    return myData
}


func (s *SmartContract) PutStateKey(ctx contractapi.TransactionContextInterface, key string, data string) (string) {

	err := ctx.GetStub().PutState(key, []byte(data))
	if err != nil {
		return "error"
	}

	return "success"
}


func main() {

	// non external start
//	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	chaincode, err := contractapi.NewChaincode(new(SmartContract))

	if err != nil {
		fmt.Printf("Error create chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting chaincode: %s", err.Error())
	}

}
