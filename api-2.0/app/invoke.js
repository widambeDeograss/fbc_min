const { Gateway, Wallets, TxEventHandler, GatewayOptions, DefaultEventHandlerStrategies, TxEventHandlerFactory } = require('fabric-network');
const fs = require('fs');
const EventStrategies = require('fabric-network/lib/impl/event/defaulteventhandlerstrategies');
const path = require("path")
const log4js = require('log4js');
const logger = log4js.getLogger('BasicNetwork');
const util = require('util')

const helper = require('./helper');
const { blockListener, contractListener } = require('./Listeners');

const invokeTransaction = async (channelName, chaincodeName, fcn, args, username, org_name, transientData) => {
    try {
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
            case "CreatePrivateDataImplicitForOrg1":
            case 'ABACTest':
            case 'CreateContract':
            case "CreateCar":
                console.log("=============")
                result = await contract.submitTransaction(fcn, args[0]);
                console.log("=============", result)
                result = {txid: result.toString()}
                break;
            case "UpdateCarOwner":
                console.log("=============")
                result = await contract.submitTransaction('SmartContract:'+fcn, args[0], args[1]);
                result = {txid: result.toString()}
                break;
            case "CreateDocument":
                result = await contract.submitTransaction('DocumentContract:'+fcn, args[0]);
                console.log(result.toString())
                result = {txid: result.toString()}
                break;
            case "Bid":
                // result = await contract.submitTransaction(fcn, args[0], args[1]);
                // console.log(result.toString())
                // result = {txid: result.toString()}

                console.log("=======checkpoint Bid1======")
                console.log(`Transient data is : ${transientData}`)
                let bidData = JSON.parse(transientData)
                console.log(`car data is : ${JSON.stringify(bidData)}`)
                key = Object.keys(bidData)[0]
                transientDataBuffer = {}
                console.log("=======checkpoint Bid2======", contract.network.channel)
                
                transientDataBuffer[key] = Buffer.from(JSON.stringify(bidData[key]))
                // await contract.addDiscoveryInterest({name: 'fabcar', collectionNames:['_implicit_org_Org3MSP']})
                console.log("==========================", contract.getDiscoveryInterests())
                // result = await contract.createTransaction(fcn).setTransient(transientDataBuffer).submit(args[0]);

                result = await contract.createTransaction(fcn).setEndorsingOrganizations('Org3MSP').setTransient(transientDataBuffer).submit(args[0]);

                // result = await contract.createTransaction(fcn).submit(args[0]);
                console.log("=======checkpoint Bid3======")
                result = {bidTxID: result.toString()}

                break;
            default:
                break;
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