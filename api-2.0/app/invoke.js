const { Gateway, Wallets, TxEventHandler, GatewayOptions, DefaultEventHandlerStrategies, TxEventHandlerFactory } = require('fabric-network');
const fs = require('fs');
const EventStrategies = require('fabric-network/lib/impl/event/defaulteventhandlerstrategies');
const path = require("path")
const log4js = require('log4js');
const logger = log4js.getLogger('BasicNetwork');
const util = require('util')

const helper = require('./helper');
const { blockListener, contractListener } = require('./Listeners');

const invokeTransaction = async (channelName, chaincodeName, fcn, args, username, org_name, transientData, args0) => {
    try {

        console.log("invokeTransaction called with params:", channelName, chaincodeName, fcn, args, username, org_name, transientData);
        
        const ccp = await helper.getCCP(org_name);
        console.log("==================", channelName, chaincodeName, fcn, args, username, org_name,)


        // const couchDBWalletStore = {
        //     url: 'http://admin:password@localhost:5990/', // Replace with your CouchDB URL
        //     walletPath: './couchdb_wallet',   // Replace with your desired wallet path
        //   };
        //   const wallet = await Wallets.newCouchDBWallet(couchDBWalletStore);

        const walletPath = await helper.getWalletPath(org_name);
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);
        
        let identity = await wallet.get(username);
        if (!identity) {
            console.log(`An identity for the user ${username} does not exist in the wallet, so registering user`);
            await helper.getRegisteredUser(username, org_name, true)
            identity = await wallet.get(username);
            console.log('Run the registerUser.js application before retrying');
            return;
        }

        console.log("-------------------------------",identity, username,wallet)


        const connectOptions = {
            wallet, identity: username, discovery: { enabled: true, asLocalhost: true }
            // eventHandlerOptions: EventStrategies.NONE
        }

        const gateway = new Gateway();
        await gateway.connect(ccp, connectOptions);

     const network = await gateway.getNetwork(channelName);
        const contract = network.getContract(chaincodeName);

        // Important: Please dont set listener here, I just showed how to set it. If we are doing here, it will set on every invoke call.
        // Instead create separate function and call it once server started, it will keep listening.
        // await contract.addContractListener(contractListener);
        // await network.addBlockListener(blockListener);


        // Multiple smartcontract in one chaincode
        let result;
        let message;

        switch (fcn) {
            case "CreateBirthRecord":
                console.log("Submitting CreateBirthRecord transaction...");
                result = await contract.submitTransaction(fcn, args[0]);  // args[0] = JSON string
                result = { txid: result.toString() };
                break;

            case "ReadBirthRecord":
                console.log("Submitting ReadBirthRecord transaction...");
                result = await contract.evaluateTransaction(fcn, args[0]);  // args[0] = recordID
                result = JSON.parse(result.toString());
                break;

            case "UpdateMedicalInfo":
                console.log("Submitting UpdateMedicalInfo transaction...", args0, args);
                result = await contract.submitTransaction(fcn, args0[0], args[1]); // args[0] = recordID, args[1] = medicalJSON
                console.log("UpdateMedicalInfo result:", result);
                
                result = { txid: result.toString() };
                break;

            case "GetHistoryForRecord":
                console.log("Submitting GetHistoryForRecord transaction...");
                result = await contract.evaluateTransaction(fcn, args[0]);  // args[0] = recordID
                result = JSON.parse(result.toString());
                break;

            case "QueryRecordsByAttribute":
                console.log("Submitting QueryRecordsByAttribute transaction...");
                result = await contract.evaluateTransaction(fcn, args[0]);  // args[0] = CouchDB query string
                result = JSON.parse(result.toString());
                break;

            default:
                throw new Error(`Function ${fcn} not supported.`);
        }


        await gateway.disconnect();

        // result = JSON.parse(result.toString());

        let response = {
            message: message,
            result
        }

        console.log("hbshfb============================", response);

        return response;


    } catch (error) {

        console.log(`Getting error: ${error}`)
        return error.message

    }
}

exports.invokeTransaction = invokeTransaction;