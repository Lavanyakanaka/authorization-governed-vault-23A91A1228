const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

async function main() {
  console.log('\n========== DEPLOYMENT START ==========' );
  console.log('Deploying Authorization-Governed Vault System...\n');

  // Get deployer account from hardhat
  const [deployer] = await ethers.getSigners();
  console.log('Deployer account:', deployer.address);
  
  // Get network info
  const network = await ethers.provider.getNetwork();
  console.log('Network ID:', network.chainId);
  console.log('Network Name:', network.name);

  // Step 1: Deploy AuthorizationManager
  console.log('\n--- Deploying AuthorizationManager ---');
  const AuthorizationManager = await ethers.getContractFactory('AuthorizationManager');
  const authManager = await AuthorizationManager.deploy();
  await authManager.deployed();
  console.log('✓ AuthorizationManager deployed at:', authManager.address);

  // Step 2: Deploy SecureVault
  console.log('\n--- Deploying SecureVault ---');
  const SecureVault = await ethers.getContractFactory('SecureVault');
  const vault = await SecureVault.deploy();
  await vault.deployed();
  console.log('✓ SecureVault deployed at:', vault.address);

  // Step 3: Initialize vault with authorization manager
  console.log('\n--- Initializing SecureVault ---');
  const initTx = await vault.initialize(authManager.address);
  await initTx.wait();
  console.log('✓ SecureVault initialized with AuthorizationManager');

  // Verify initialization
  const isInitialized = await vault.isInitialized();
  console.log('  Initialization verified:', isInitialized);

  // Output deployment summary
  const deploymentSummary = {
    network: {
      id: network.chainId,
      name: network.name,
      timestamp: new Date().toISOString(),
    },
    contracts: {
      AuthorizationManager: {
        address: authManager.address,
        deploymentBlock: authManager.deploymentTransaction()?.blockNumber,
      },
      SecureVault: {
        address: vault.address,
        authorizationManagerAddress: authManager.address,
        deploymentBlock: vault.deploymentTransaction()?.blockNumber,
      },
    },
    deployer: deployer.address,
  };

  // Write deployment summary to file
  const deploymentPath = path.join(__dirname, '..', 'deployment.json');
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentSummary, null, 2));
  console.log('\n--- Deployment Summary ---');
  console.log(JSON.stringify(deploymentSummary, null, 2));
  console.log('\n✓ Deployment summary written to deployment.json');
  console.log('\n========== DEPLOYMENT SUCCESS ==========\n');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Deployment failed:', error);
    process.exit(1);
  });
