#!/bin/bash

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${CAPORT}/$3/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        ./ccp-template.json
}

ORG=1
P0PORT=3051
CAPORT=3054
PEERPEM=../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/tlscacerts/tls-localhost-3054-ca-org1-example-com.pem
CAPEM=../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/msp/tlscacerts/ca.crt

echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM )" > connection-org1.json

ORG=2
P0PORT=5051
CAPORT=4054
PEERPEM=../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/tlscacerts/tls-localhost-4054-ca-org2-example-com.pem
CAPEM=../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/msp/tlscacerts/ca.crt

echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > connection-org2.json

ORG=3
P0PORT=6051
CAPORT=1054
PEERPEM=../../artifacts/channel/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/tlscacerts/tls-localhost-1054-ca-org3-example-com.pem
CAPEM=../../artifacts/channel/crypto-config/peerOrganizations/org3.example.com/msp/tlscacerts/ca.crt


echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > connection-org3.json