# Manual Test Guide

## Script Validation Results

✅ **All 12 scripts are valid and ready for use!**
- Syntax: All scripts have valid bash syntax
- Permissions: All scripts are executable
- Shebang: All scripts have proper shebang
- Error Handling: All scripts have proper error handling

## Manual Testing Commands

### 1. **Setup and Deployment** (Main Script)
```bash
# This is the main script you should test first
./setup-and-deploy.sh
```
**What it does:**
- Validates prerequisites (terraform, gcloud, docker, kubectl)
- Configures GCP project and regions
- Updates configuration files
- Enables GCP APIs
- Builds and pushes Docker image
- Deploys infrastructure with Terraform
- Provides post-deployment information

**Expected behavior:**
- Interactive prompts for project confirmation and region selection
- Automatic configuration updates
- Docker image build and push
- Terraform deployment (15-20 minutes)
- Success message with next steps

### 2. **Infrastructure Testing**
```bash
# Test infrastructure components
./test-infrastructure.sh
```
**What it does:**
- Tests Terraform configuration
- Validates GKE clusters
- Checks application deployment
- Verifies monitoring stack
- Tests security configurations

**Expected behavior:**
- Comprehensive infrastructure validation
- Pass/fail results for each component
- Summary of all tests

### 3. **CI/CD Testing**
```bash
# Test CI/CD pipeline components
./test-cicd.sh
```
**What it does:**
- Validates GitHub Actions workflow
- Tests Docker configuration
- Checks canary deployment setup
- Verifies rollback strategies
- Tests security scanning

**Expected behavior:**
- CI/CD pipeline validation
- Configuration file checks
- Deployment strategy validation

### 4. **Canary and Rollback Testing**
```bash
# Test canary deployments and rollback functionality
./test-canary-rollback.sh [GATEWAY_IP] [TOTAL_REQUESTS]
```
**What it does:**
- Tests canary deployment setup
- Validates traffic distribution (80/20 split)
- Tests health endpoints
- Verifies rollback functionality
- Monitors error rates

**Expected behavior:**
- Canary deployment validation
- Traffic distribution analysis
- Rollback testing
- Performance metrics

### 5. **Load Testing**
```bash
# Test application performance under load
./load-test.sh [GATEWAY_IP]
```
**What it does:**
- Tests response times
- Validates concurrent request handling
- Tests auto-scaling
- Monitors resource utilization

**Expected behavior:**
- Performance metrics
- Auto-scaling validation
- Load balancer performance

### 6. **Disaster Recovery Testing**
```bash
# Test disaster recovery capabilities
./disaster-recovery-test.sh
```
**What it does:**
- Tests failover capabilities
- Validates cross-region connectivity
- Tests RTO/RPO compliance
- Verifies data consistency

**Expected behavior:**
- Failover simulation
- Recovery time validation
- Cross-region connectivity tests

### 7. **Master Test Suite**
```bash
# Run all tests together
./run-all-tests.sh
```
**What it does:**
- Runs all individual test scripts
- Provides comprehensive validation
- Generates overall test summary

**Expected behavior:**
- Complete infrastructure validation
- All component testing
- Final success/failure summary

### 8. **Infrastructure Cleanup**
```bash
# Clean up all resources (use with caution!)
./destroy.sh
```
**What it does:**
- Destroys all deployed infrastructure
- Cleans up Terraform state
- Removes local files

**Expected behavior:**
- Complete resource cleanup
- Confirmation prompts
- Clean state

## Testing Order Recommendation

1. **First**: Run `./setup-and-deploy.sh` to deploy the infrastructure
2. **Second**: Run `./run-all-tests.sh` to validate everything
3. **Third**: Test individual components as needed
4. **Finally**: Use `./destroy.sh` to clean up (when done testing)

## Important Notes

- **Interactive Scripts**: `setup-and-deploy.sh` has interactive prompts
- **GCP Requirements**: You need a GCP project with billing enabled
- **Time**: Full deployment takes 15-20 minutes
- **Cost**: GCP resources will incur charges
- **Cleanup**: Always run `./destroy.sh` when done testing

## Troubleshooting

If any script fails:
1. Check GCP authentication: `gcloud auth list`
2. Verify project: `gcloud config get-value project`
3. Check prerequisites: `terraform --version`, `kubectl version`, `docker --version`
4. Review error messages in the script output

## Success Criteria

✅ **All scripts run without syntax errors**
✅ **Infrastructure deploys successfully**
✅ **All tests pass**
✅ **Application is accessible**
✅ **Monitoring is working**
✅ **Security configurations are active**

The scripts are ready for manual testing!
