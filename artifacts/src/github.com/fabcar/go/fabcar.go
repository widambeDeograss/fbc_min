package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-chaincode-go/pkg/cid"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	"github.com/hyperledger/fabric/common/flogging"
)

// SmartContract provides functions for managing BirthRecords
type SmartContract struct {
	contractapi.Contract
}

var logger = flogging.MustGetLogger("fabcar_cc")

// BirthRecord defines the full birth registration schema
type BirthRecord struct {
	RecordID   string      `json:"recordID"`
	Child      ChildInfo   `json:"child"`
	Parents    ParentInfo  `json:"parents"`
	Contact    ContactInfo `json:"contact"`
	Medical    MedicalInfo `json:"medical"`
	CreatedAt  uint64      `json:"createdAt"`
	CreatedBy  string      `json:"createdBy"` // MSP ID or userID
}

// ChildInfo captures newborn details
type ChildInfo struct {
	FirstName   string `json:"firstName"`
	MiddleName  string `json:"middleName"`
	LastName    string `json:"lastName"`
	DateOfBirth string `json:"dateOfBirth"`
	TimeOfBirth string `json:"timeOfBirth"`
	Gender      string `json:"gender"`
	WeightGrams int    `json:"weightGrams"`
}

// ParentInfo captures mother & father details
type ParentInfo struct {
	MotherFirstName string `json:"motherFirstName"`
	MotherLastName  string `json:"motherLastName"`
	MotherID        string `json:"motherID"`
	FatherFirstName string `json:"fatherFirstName"`
	FatherLastName  string `json:"fatherLastName"`
	FatherID        string `json:"fatherID"`
}

// ContactInfo captures address & contact
type ContactInfo struct {
	Address      string `json:"address"`
	City         string `json:"city"`
	State        string `json:"state"`
	PostalCode   string `json:"postalCode"`
	PhoneNumber  string `json:"phoneNumber"`
	Email        string `json:"email"`
}

// MedicalInfo captures delivery & notes
type MedicalInfo struct {
	DeliveryType     string `json:"deliveryType"`
	HospitalRecordNo string `json:"hospitalRecordNo"`
	Physician        string `json:"physician"`
	MedicalNotes     string `json:"medicalNotes"`
}

// CreateBirthRecord registers a new birth record on the ledger
func (s *SmartContract) CreateBirthRecord(ctx contractapi.TransactionContextInterface, recordJSON string) (string, error) {
	if len(recordJSON) == 0 {
		return "", fmt.Errorf("must provide birth record data")
	}

	var record BirthRecord
	if err := json.Unmarshal([]byte(recordJSON), &record); err != nil {
		return "", fmt.Errorf("invalid input JSON: %s", err)
	}

	// Enforce MSP-based authorization if needed
	mspID, err := cid.GetMSPID(ctx.GetStub())
	if err != nil {
		return "", fmt.Errorf("failed to get client MSP ID: %s", err)
	}
	record.CreatedBy = mspID
	record.CreatedAt = uint64(time.Now().Unix())

	// Create composite key
	key, err := ctx.GetStub().CreateCompositeKey("BirthRecord", []string{record.RecordID})
	if err != nil {
		return "", fmt.Errorf("failed to create composite key: %s", err)
	}

	asBytes, err := json.Marshal(record)
	if err != nil {
		return "", fmt.Errorf("failed to marshal record: %s", err)
	}

	if err := ctx.GetStub().PutState(key, asBytes); err != nil {
		return "", fmt.Errorf("failed to put state: %s", err)
	}
	ctx.GetStub().SetEvent("CreateBirthRecord", asBytes)
	return ctx.GetStub().GetTxID(), nil
}

// ReadBirthRecord returns the birth record stored in the world state with given id
func (s *SmartContract) ReadBirthRecord(ctx contractapi.TransactionContextInterface, recordID string) (*BirthRecord, error) {
	if len(recordID) == 0 {
		return nil, fmt.Errorf("recordID must be specified")
	}
	key, err := ctx.GetStub().CreateCompositeKey("BirthRecord", []string{recordID})
	if err != nil {
		return nil, fmt.Errorf("failed to create composite key: %s", err)
	}

	data, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %s", err)
	}
	if data == nil {
		return nil, fmt.Errorf("birth record %s does not exist", recordID)
	}
	var record BirthRecord
	if err := json.Unmarshal(data, &record); err != nil {
		return nil, err
	}
	return &record, nil
}

// UpdateMedicalInfo allows updating only the medical section
func (s *SmartContract) UpdateMedicalInfo(ctx contractapi.TransactionContextInterface, recordID string, medicalJSON string) (string, error) {
	record, err := s.ReadBirthRecord(ctx, recordID)
	if err != nil {
		return "", err
	}
	var med MedicalInfo
	if err := json.Unmarshal([]byte(medicalJSON), &med); err != nil {
		return "", fmt.Errorf("invalid medical JSON: %s", err)
	}
	record.Medical = med

	key, err := ctx.GetStub().CreateCompositeKey("BirthRecord", []string{recordID})
	if err != nil {
		return "", fmt.Errorf("failed to create composite key: %s", err)
	}

	asBytes, err := json.Marshal(record)
	if err != nil {
		return "", fmt.Errorf("failed to marshal record: %s", err)
	}

	if err := ctx.GetStub().PutState(key, asBytes); err != nil {
		return "", err
	}
	return ctx.GetStub().GetTxID(), nil
}

// GetHistoryForRecord returns the transaction history for a record
func (s *SmartContract) GetHistoryForRecord(ctx contractapi.TransactionContextInterface, recordID string) (string, error) {
	key, err := ctx.GetStub().CreateCompositeKey("BirthRecord", []string{recordID})
	if err != nil {
		return "", fmt.Errorf("failed to create composite key: %s", err)
	}

	iter, err := ctx.GetStub().GetHistoryForKey(key)
	if err != nil {
		return "", err
	}
	defer iter.Close()

	var buffer bytes.Buffer
	buffer.WriteString("[")

	first := true
	for iter.HasNext() {
		resp, err := iter.Next()
		if err != nil {
			return "", err
		}
		if !first {
			buffer.WriteString(",")
		}
		buffer.WriteString(fmt.Sprintf(
			`{"TxId":"%s","Value":%s,"Timestamp":"%s","IsDelete":"%t"}`,
			resp.TxId,
			string(resp.Value),
			time.Unix(resp.Timestamp.Seconds, int64(resp.Timestamp.Nanos)).Format(time.RFC3339),
			resp.IsDelete,
		))
		first = false
	}
	buffer.WriteString("]")
	return buffer.String(), nil
}

// QueryRecordsByAttribute performs a rich query against CouchDB
func (s *SmartContract) QueryRecordsByAttribute(ctx contractapi.TransactionContextInterface, queryString string) ([]BirthRecord, error) {
	iter, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, err
	}
	defer iter.Close()

	var results []BirthRecord
	for iter.HasNext() {
		resp, err := iter.Next()
		if err != nil {
			return nil, err
		}
		var record BirthRecord
		if err := json.Unmarshal(resp.Value, &record); err != nil {
			return nil, err
		}
		results = append(results, record)
	}
	return results, nil
}

func main() {
	chaincode, err := contractapi.NewChaincode(new(SmartContract))
	if err != nil {
		logger.Errorf("Error creating birth chaincode: %s", err)
		return
	}
	if err := chaincode.Start(); err != nil {
		logger.Errorf("Error starting birth chaincode: %s", err)
	}
}
