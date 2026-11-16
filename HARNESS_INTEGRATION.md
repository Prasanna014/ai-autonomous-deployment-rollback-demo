# Harness Deployment Integration Guide

This guide shows how to integrate the AI Autonomous Deployment Rollback Demo with Harness Continuous Delivery for automated deployments and rollbacks.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Harness Setup](#harness-setup)
3. [Deployment Pipeline](#deployment-pipeline)
4. [Automatic Rollback](#automatic-rollback)
5. [Testing](#testing)
6. [Advanced Scenarios](#advanced-scenarios)

## Prerequisites

### Required

- Harness account (https://app.harness.io)
- GitHub repository (with this code)
- Linux server for deployment (Ubuntu 18.04+, CentOS 7+, etc.)
- SSH access to target server
- Python 3.7+, pip3 installed on target server

### Optional

- Harness Delegate installed on your infrastructure
- GitHub webhook integration enabled

## Harness Setup

### Step 1: Create Harness Account

1. Go to https://app.harness.io
2. Sign up for free tier account
3. Create organization (e.g., "Demo")
4. Create project (e.g., "Deployment Demo")

### Step 2: Add GitHub Connector

1. Go to **Connectors** → **Create New**
2. Select **GitHub**
3. Configure:
   - **Name**: GitHub Repo
   - **GitHub URL**: https://github.com/
   - **Authentication**: 
     - Generate GitHub Personal Access Token (https://github.com/settings/tokens)
     - Select scope: `repo`, `workflow`
     - Use token in Harness
4. Test connection → Save

### Step 3: Add SSH Connector (for Linux Server)

1. Go to **Connectors** → **Create New**
2. Select **SSH**
3. Configure:
   - **Name**: Linux Server
   - **Host**: Your server IP/hostname
   - **Port**: 22
   - **Authentication**: 
     - Username: `ubuntu` or your deployment user
     - SSH Key: Upload your private key or use password
4. Test connection → Save

### Step 4: Create Environment

1. Go to **Environments** → **Create New**
2. Configure:
   - **Name**: Production
   - **Environment type**: Production
   - **Infrastructure**: Add SSH connector
3. Save

## Deployment Pipeline

### Create CD Pipeline

1. Go to **Pipelines** → **New Pipeline**
2. Name: `Deploy Demo App`
3. Organization and Project: Select your project

### Stage 1: Clone & Deploy

```yaml
stage:
  name: Deploy
  type: Deployment
  spec:
    serviceConfig:
      serviceRef: demo-app
      serviceVariables:
        - name: version
          type: String
          value: <+trigger.payload.commits[0].commitId>
    infrastructureConfig:
      infrastructureRef: prod-linux
    executionSteps:
      - step:
          name: Clone Repository
          identifier: clone_repo
          type: ShellScript
          spec:
            shell: Bash
            command: |
              cd /opt/demo
              git clone https://github.com/YOUR_USERNAME/ai-autonomous-deployment-rollback-demo.git .
              git checkout main
      
      - step:
          name: Install Dependencies
          identifier: install_deps
          type: ShellScript
          spec:
            shell: Bash
            command: |
              cd /opt/demo
              pip3 install -r requirements.txt
      
      - step:
          name: Stop Current Version
          identifier: stop_old
          type: ShellScript
          spec:
            shell: Bash
            command: |
              PID=$(lsof -i :8080 -t 2>/dev/null || echo "")
              if [ -n "$PID" ]; then
                kill -SIGTERM $PID 2>/dev/null || true
                sleep 2
              fi
      
      - step:
          name: Start Application
          identifier: start_app
          type: ShellScript
          spec:
            shell: Bash
            command: |
              cd /opt/demo
              nohup python3 app.py > application.log 2>&1 &
              sleep 3
      
      - step:
          name: Health Check
          identifier: health_check
          type: Http
          spec:
            url: http://<+infrastructure.variables.server_ip>:8080/health
            method: GET
            assertion: <+response.status> == 200
            timeout: 30
          rollbackSteps:
            - step:
                name: Rollback
                identifier: rollback_on_failure
                type: ShellScript
                spec:
                  shell: Bash
                  command: |
                    cd /opt/demo
                    bash rollback.sh
```

### Create Service

1. Go to **Services** → **Create New**
2. Configure:
   - **Name**: demo-app
   - **Service Type**: Other
   - **Deployment Type**: SSH
3. Add artifact (optional):
   - Source: GitHub
   - Repository: ai-autonomous-deployment-rollback-demo
   - Branch: main

## Automatic Rollback

### Rollback Policy

In your pipeline stage:

```yaml
rollbackPolicy:
  onStepFailure: true
  onStageFailure: true
  
failureStrategies:
  - onFailure: All
    action: Rollback
    
postDeploymentSteps:
  - step:
      name: Verify Deployment
      identifier: verify
      type: Http
      spec:
        url: http://<+infrastructure.variables.server_ip>:8080/health
        method: GET
        timeout: 30
        retryCount: 3
        retryInterval: 5
      failureStrategies:
        - onFailure: All
          action: Rollback
```

### Custom Rollback Step

```yaml
- step:
    name: Custom Rollback
    identifier: custom_rollback
    type: ShellScript
    spec:
      shell: Bash
      command: |
        cd /opt/demo
        bash rollback.sh
        
        # Verify rollback succeeded
        for i in {1..10}; do
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
          if [ "$STATUS" == "200" ]; then
            echo "Rollback successful"
            exit 0
          fi
          sleep 2
        done
        
        echo "Rollback verification failed"
        exit 1
```

## Testing

### Test 1: Basic Deployment

1. Go to **Pipelines** → Your pipeline
2. Click **Run**
3. Select branch: `main`
4. Click **Run Pipeline**
5. Monitor execution
6. Verify app is running: `curl http://your-server:8080/health`

### Test 2: Triggered Rollback

1. Update version in `version.txt`: `echo "2.0.0" > version.txt`
2. Commit and push: `git push`
3. Run deployment pipeline
4. Application starts
5. Add failure condition to `health()` endpoint
6. Commit broken version: `echo "2.1.0" > version.txt`
7. Push and deploy
8. Pipeline should detect health check failure
9. Automatic rollback should restore version 2.0.0
10. Verify: `curl http://your-server:8080/health | grep version`

### Test 3: Deployment Failure Scenarios

#### Scenario A: Invalid Import
```python
# In app.py, uncomment the line
from non_existent_module import something
```
1. Commit and push
2. Run deployment - should fail
3. Automatic rollback should restore previous version
4. Health check should pass

#### Scenario B: Health Check Failure
```python
# In app.py, uncomment the line
return jsonify({"status": "DOWN"}), 503
```
1. Commit and push
2. Run deployment - starts but health check fails
3. Automatic rollback triggered
4. Previous working version restored

## Advanced Scenarios

### Multi-Stage Deployment (Canary)

```yaml
stages:
  - stage:
      name: Dev
      spec:
        execution: Sequential
  
  - stage:
      name: Staging
      spec:
        execution: Sequential
        
  - stage:
      name: Canary
      spec:
        execution: Canary
        canaryDetails:
          canaryInstances: 10%
          canaryInterval: 5m
          
  - stage:
      name: Production
      spec:
        execution: Sequential
        dependsOn:
          - Canary
```

### AI-Based Rollback Analysis

Harness AI (CV - Continuous Verification) can automatically:

1. **Collect Metrics**: Application logs, health checks, system metrics
2. **Detect Anomalies**: AI identifies unusual patterns
3. **Trigger Rollback**: Automatic rollback if anomalies detected

Configure in pipeline:

```yaml
verificationStep:
  name: AI Verification
  type: ContinuousVerification
  spec:
    monitoringSources:
      - name: Application Logs
        type: Log
        spec:
          query: "ERROR OR CRITICAL"
          
      - name: Health Metrics
        type: Metrics
        spec:
          metric: http_requests_total
          
    aiThresholds:
      errorBudget: 5%
      anomalyDetection: true
```

### Scheduled Rollback Drills

```yaml
trigger:
  type: Scheduled
  spec:
    schedule: "0 2 * * 1"  # Every Monday at 2 AM
    event:
      name: "Weekly Rollback Drill"
      type: Deployment
      actions:
        - Deploy version N
        - Verify
        - Trigger rollback to version N-1
        - Verify rollback
        - Report results
```

### Integration with GitHub

#### Auto-Deploy on PR Merge

```yaml
trigger:
  type: WebhookTrigger
  spec:
    event: PullRequest
    action: Merged
    branch: main
    autoDeployment:
      enabled: true
      rollbackOnFailure: true
```

#### Deployment Status Badge

Add to README.md:

```markdown
[![Deploy Status](https://app.harness.io/api/badge/deployment?projectId=YOUR_PROJECT_ID&pipelineId=YOUR_PIPELINE_ID&branch=main)](https://app.harness.io/ng/account/YOUR_ACCOUNT/home/orgs/DEFAULT/projects/YOUR_PROJECT/deployments)
```

## Monitoring and Analytics

### View Deployment Analytics

1. Go to **Deployments** → **Deployment Dashboard**
2. Track:
   - Deployment frequency
   - Deployment success rate
   - Mean time to rollback
   - Mean time to recovery
   - Change failure rate

### Custom Notifications

Configure Slack/Email notifications on:
- Deployment started
- Deployment succeeded
- Deployment failed
- Rollback triggered
- Rollback completed

## Troubleshooting Harness Deployments

### Deployment Fails with SSH Error
- Verify SSH connector credentials
- Test SSH access manually: `ssh -i /path/to/key user@host`
- Check firewall allows port 22

### Health Check Timeout
- Verify app is actually running: `ps aux | grep python3`
- Check app logs: `tail -50 application.log`
- Ensure app listens on correct port: `netstat -tlnp | grep 8080`

### Rollback Doesn't Execute
- Check backups exist: `ls -la /opt/demo/backups/`
- Verify rollback.sh has execute permissions: `chmod +x /opt/demo/rollback.sh`
- Check script logs for errors

### Application Starts but Health Check Fails
- Test manually: `curl http://localhost:8080/health`
- Check app logs for startup errors
- Verify all dependencies installed: `pip3 list | grep Flask`

## Example Complete Pipeline YAML

```yaml
pipeline:
  name: Deploy Demo App
  identifier: deploy_demo
  projectIdentifier: demo-project
  orgIdentifier: demo-org
  
  stages:
    - stage:
        name: Deploy
        identifier: deploy
        type: Deployment
        spec:
          deploymentType: SSH
          service:
            useFromStage: demo-app
          environment:
            environmentRef: prod
            deployToAll: false
            infrastructureDefinitions:
              - infrastructureDefinitionRef: linux-server
          
          steps:
            - step:
                name: Clone
                identifier: clone
                type: ShellScript
                spec:
                  shell: Bash
                  command: |
                    cd /opt/demo
                    git pull origin main
            
            - step:
                name: Deploy
                identifier: deploy
                type: ShellScript
                spec:
                  shell: Bash
                  command: |
                    cd /opt/demo
                    bash deploy.sh
            
            - step:
                name: Health
                identifier: health
                type: Http
                spec:
                  url: http://localhost:8080/health
                  method: GET
                  assertion: <+response.status> == 200
```

## Resources

- [Harness Documentation](https://docs.harness.io)
- [Harness Community](https://community.harness.io)
- [Harness University](https://university.harness.io)
- [Continuous Verification Guide](https://docs.harness.io/article/b6mf10d9l5)

## Next Steps

1. Create your Harness pipeline
2. Test basic deployment
3. Test rollback scenario
4. Integrate with GitHub webhooks
5. Set up monitoring and alerts
6. Create failure injection tests
7. Document your deployment runbooks
