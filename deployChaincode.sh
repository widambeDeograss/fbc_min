export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.fabcar.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export FABRIC_CFG_PATH=${PWD}/artifacts/channel/config/

export CHANNEL_NAME=fabcarchannel

setGlobalsForOrderer() {
    export CORE_PEER_LOCALMSPID="OrdererMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.fabcar.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp

}

setGlobalsForPeer0Org1() {
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:3051
}

setGlobalsForOrg1() {
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/User1@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:3051
}

setGlobalsForPeer0Org2() {
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:5051

}

setGlobalsForPeer0Org3(){
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG3_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
    export CORE_PEER_ADDRESS=localhost:6051
    
}

presetup() {
    echo Vendoring Go dependencies ...
    pushd ./artifacts/src/github.com/fabcar/go
    GO111MODULE=on go mod vendor
    popd
    echo Finished vendoring Go dependencies
}
# presetup

CHANNEL_NAME="fabcarchannel"
CC_RUNTIME_LANGUAGE="golang"
VERSION="1"
SEQUENCE=1
CC_SRC_PATH="./artifacts/src/github.com/fabcar/go"
CC_NAME="fabcar"

packageChaincode() {
    rm -rf ${CC_NAME}.tar.gz
    setGlobalsForPeer0Org1
    peer lifecycle chaincode package ${CC_NAME}.tar.gz \
        --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} \
        --label ${CC_NAME}_${VERSION}
    echo "===================== Chaincode is packaged ===================== "
}
# packageChaincode

installChaincode() {
    setGlobalsForPeer0Org1
    peer lifecycle chaincode install ${CC_NAME}.tar.gz
    echo "===================== Chaincode is installed on peer0.org1 ===================== "

    setGlobalsForPeer0Org2
    peer lifecycle chaincode install ${CC_NAME}.tar.gz
    echo "===================== Chaincode is installed on peer0.org2 ===================== "

    setGlobalsForPeer0Org3
    peer lifecycle chaincode install ${CC_NAME}.tar.gz
    echo "===================== Chaincode is installed on peer0.org3 ===================== "
}

# installChaincode
queryInstalled() {
    setGlobalsForPeer0Org1

    echo "🔍 Querying installed chaincode on peer0.org1..."

    peer lifecycle chaincode queryinstalled >&log.txt

    cat log.txt

    PACKAGE_ID=$(sed -n "/${CC_NAME}_${VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)

    if [ -z "$PACKAGE_ID" ]; then
        echo "❌ ERROR: Could not extract PACKAGE_ID from log.txt. Make sure the chaincode is installed and the label matches."
        exit 1
    fi

    echo "📦 PackageID is: ${PACKAGE_ID}"
    echo "✅ Chaincode query installed successfully on peer0.org1"
}


# queryInstalled

# --collections-config ./artifacts/private-data/collections_config.json \
#         --signature-policy "OR('Org1MSP.member','Org2MSP.member')" \

approveForMyOrg1() {
    setGlobalsForPeer0Org1
    peer lifecycle chaincode approveformyorg \
        -o localhost:3050 \
        --ordererTLSHostnameOverride orderer.fabcar.example.com \
        --tls \
        --cafile $ORDERER_CA \
        --channelID $CHANNEL_NAME \
        --name ${CC_NAME} \
        --version ${VERSION} \
        --package-id ${PACKAGE_ID} \
        --sequence ${SEQUENCE} \
        --init-required \
        --peerAddresses localhost:3051 \
        --tlsRootCertFiles $PEER0_ORG1_CA

    echo "===================== ✅ Chaincode approved from Org1 ====================="
}

checkCommitReadyness() {
    setGlobalsForPeer0Org1
    peer lifecycle chaincode checkcommitreadiness \
        --channelID $CHANNEL_NAME \
        --name ${CC_NAME} \
        --version ${VERSION} \
        --sequence ${SEQUENCE} \
        --init-required \
        --output json

    echo "===================== 🔎 Commit Readiness checked from Org1 ====================="
}


# checkCommitReadyness

approveForMyOrg2() {
    setGlobalsForPeer0Org2

    peer lifecycle chaincode approveformyorg -o localhost:3050 \
        --ordererTLSHostnameOverride orderer.fabcar.example.com --tls $CORE_PEER_TLS_ENABLED \
        --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} \
        --version ${VERSION} --init-required --package-id ${PACKAGE_ID} \
        --sequence ${SEQUENCE}

    echo "===================== chaincode approved from org 2 ===================== "
}

# queryInstalled
# approveForMyOrg2

checkCommitReadyness() {

    setGlobalsForPeer0Org2
    peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME \
        --peerAddresses localhost:5051 --tlsRootCertFiles $PEER0_ORG2_CA \
        --name ${CC_NAME} --version ${VERSION} --sequence ${VERSION} --output json --init-required
    echo "===================== checking commit readyness from org 1 ===================== "
}

# checkCommitReadyness

approveForMyOrg3() {
    setGlobalsForPeer0Org3

    peer lifecycle chaincode approveformyorg -o localhost:3050 \
        --ordererTLSHostnameOverride orderer.fabcar.example.com --tls $CORE_PEER_TLS_ENABLED \
        --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} \
        --version ${VERSION} --init-required --package-id ${PACKAGE_ID} \
        --sequence ${SEQUENCE}

    echo "===================== chaincode approved from org 2 ===================== "
}

# queryInstalled
# approveForMyOrg3

checkCommitReadyness() {

    setGlobalsForPeer0Org3
    peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME \
        --peerAddresses localhost:6051 --tlsRootCertFiles $PEER0_ORG3_CA \
        --name ${CC_NAME} --version ${VERSION} --sequence ${VERSION} --output json --init-required
    echo "===================== checking commit readyness from org 1 ===================== "
}

# checkCommitReadyness

commitChaincodeDefination() {
    setGlobalsForPeer0Org1
    peer lifecycle chaincode commit -o localhost:3050 --ordererTLSHostnameOverride orderer.fabcar.example.com \
        --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA \
        --channelID $CHANNEL_NAME --name ${CC_NAME} \
        --peerAddresses localhost:3051 --tlsRootCertFiles $PEER0_ORG1_CA \
        --peerAddresses localhost:5051 --tlsRootCertFiles $PEER0_ORG2_CA \
        --peerAddresses localhost:6051 --tlsRootCertFiles $PEER0_ORG3_CA \
        --version ${VERSION} --sequence ${SEQUENCE} --init-required

}

# commitChaincodeDefination

queryCommitted() {
    setGlobalsForPeer0Org1
    peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME}

}

# queryCommitted

chaincodeInvokeInit() {
    setGlobalsForPeer0Org1
    peer chaincode invoke -o localhost:3050 \
        --ordererTLSHostnameOverride orderer.fabcar.example.com \
        --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA \
        -C $CHANNEL_NAME -n ${CC_NAME} \
        --peerAddresses localhost:3051 --tlsRootCertFiles $PEER0_ORG1_CA \
        --peerAddresses localhost:5051 --tlsRootCertFiles $PEER0_ORG2_CA \
         --peerAddresses localhost:6051 --tlsRootCertFiles $PEER0_ORG3_CA \
        --isInit -c '{"Args":[]}'

}

# chaincodeInvokeInit

chaincodeInvoke() {
    setGlobalsForPeer0Org1

    BIRTH_DATA=$(cat <<EOF
{
  "recordID": "REC001",
  "child": {
    "firstName": "Aisha",
    "middleName": "Masoud",
    "lastName": "Mussa",
    "dateOfBirth": "2025-01-25",
    "timeOfBirth": "10:45",
    "gender": "Female",
    "weightGrams": 4100
  },
  "parents": {
    "motherFirstName": "Mariam",
    "motherLastName": "Mussa",
    "motherID": "IDM33345",
    "fatherFirstName": "Masoud",
    "fatherLastName": "Mussa",
    "fatherID": "IDF66890"
  },
  "contact": {
    "address": "334 Kigamboni",
    "city": "Dar es Salaam",
    "state": "Dar",
    "postalCode": "11101",
    "phoneNumber": "+255712445678",
    "email": "masoud@example.com"
  },
  "medical": {
    "deliveryType": "vaginal delivery",
    "hospitalRecordNo": "HR0002",
    "physician": "Dr. Abdul",
    "medicalNotes": "Normal delivery,no complications"
  }
}
EOF
)
    FLATTENED_JSON=$(echo "$BIRTH_DATA" | jq -c .)
    FLATTENED_JSON_ESCAPED=$(printf '%s' "$FLATTENED_JSON" | sed 's/"/\\"/g')

    # Create Car
    peer chaincode invoke -o localhost:3050 \
        --ordererTLSHostnameOverride orderer.fabcar.example.com \
        --tls $CORE_PEER_TLS_ENABLED \
        --cafile $ORDERER_CA \
        -C $CHANNEL_NAME -n ${CC_NAME}  \
        --peerAddresses localhost:3051 --tlsRootCertFiles $PEER0_ORG1_CA \
        --peerAddresses localhost:5051 --tlsRootCertFiles $PEER0_ORG2_CA   \
        -c "{\"function\":\"CreateBirthRecord\",\"Args\":[\"$FLATTENED_JSON_ESCAPED\"]}"


}

# chaincodeInvoke

chaincodeInvokeDeleteAsset() {
    setGlobalsForPeer0Org1

    # Create Car
    peer chaincode invoke -o localhost:3050 \
        --ordererTLSHostnameOverride orderer.fabcar.example.com \
        --tls $CORE_PEER_TLS_ENABLED \
        --cafile $ORDERER_CA \
        -C $CHANNEL_NAME -n ${CC_NAME}  \
        --peerAddresses localhost:3051 --tlsRootCertFiles $PEER0_ORG1_CA \
        --peerAddresses localhost:5051 --tlsRootCertFiles $PEER0_ORG2_CA   \
        -c '{"function": "DeleteCarById","Args":["2"]}'

}

# chaincodeInvokeDeleteAsset

chaincodeQuery() {
    setGlobalsForPeer0Org1
    # setGlobalsForOrg1
    peer chaincode query -C $CHANNEL_NAME -n ${CC_NAME} -c '{"function": "GetCarById","Args":["1"]}'
}

# chaincodeQuery

# Run this function if you add any new dependency in chaincode
# presetup
# packageChaincode
# installChaincode
# queryInstalled
# approveForMyOrg1
# checkCommitReadyness
# approveForMyOrg2
# checkCommitReadyness
# approveForMyOrg3
# checkCommitReadyness
# commitChaincodeDefination
# queryCommitted
# chaincodeInvokeInit
# sleep 5
chaincodeInvoke
# sleep 3
# chaincodeQuery
