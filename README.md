# Dynamic Challenge Assessment Engine

This repository contains the implementation of a Dynamic Challenge Assessment Engine for Travelers Capture The Flag (CTF) events. The system enables instructors to create challenges that can be automatically assessed without modifying the core engine.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Implementation Components](#implementation-components)
- [Installation](#installation)
- [Usage](#usage)
- [Customization](#customization)
- [Team Account Setup](#team-account-setup)
- [Security Considerations](#security-considerations)
- [Monitoring and Operations](#monitoring-and-operations)
- [Next Steps](#next-steps)

## Overview

The Dynamic Challenge Assessment Engine is designed to support Travelers CTF events. The system follows a hub-and-spoke model with a central Challenge Management Account containing the assessment engine and challenge repository, connected to multiple Team Accounts where participants deploy their solutions.

Key features:

- **Decentralized challenge development**: Multiple engineers can create challenges independently
- **Dynamic code loading**: Challenge-specific check functions are loaded and executed at runtime
- **Automated assessment**: Participant solutions are evaluated against predefined reliability criteria
- **Secure cross-account access**: Strict security boundaries between participant environments
- **Real-time feedback**: Participants receive detailed feedback on their implementations
- **Comprehensive monitoring**: Dashboard and alerts for monitoring system health

## Architecture

The system architecture consists of the following key components:

1. **Storage Layer**
   - S3 Challenge Repository: Stores challenge definitions, check functions, and resources
   - DynamoDB Challenge Registry: Central database of all available challenges
   - DynamoDB Assessment Results: Records participant assessment outcomes

2. **Compute Layer**
   - Assessment Engine Lambda: Core function that dynamically loads and executes check functions
   - Custom Resource Lambda: Handles sample challenge upload and registration

3. **API Layer**
   - Challenge Management API: RESTful endpoints for managing challenges
   - Assessment API: Endpoint for triggering assessments and retrieving results

4. **Security Layer**
   - IAM Roles with least-privilege permissions
   - Cross-account access with External ID for enhanced security
   - S3 bucket policies to restrict access

5. **Monitoring Layer**
   - CloudWatch Dashboard: Real-time visualization of assessment metrics
   - CloudWatch Alarms: Alerts for system health monitoring
   - SNS Topics: Notification mechanism for important events

## Implementation Components

This implementation provides two key components:

### 1. Preparation Script

The `prepare-ctf-infrastructure.sh` script handles all preliminary work before CloudFormation deployment:

- Sets up environment variables for consistent resource naming
- Creates necessary IAM policy and trust relationship JSON files
- Prepares the Lambda function code for the assessment engine
- Generates sample challenge files (config.json and check-functions.py)
- Creates CloudWatch dashboard configuration
- Prepares templates for team accounts and test participants
- Packages the Lambda function into a deployment-ready ZIP file

### 2. CloudFormation Template

The `cloudformation-template.yaml` defines all infrastructure resources needed for the engine:

- Storage resources (S3 buckets, DynamoDB tables)
- IAM roles and policies
- Lambda functions
- API Gateway configuration
- SNS topics for notifications
- CloudWatch resources (dashboard, alarms)
- Custom resource for sample challenge upload

## Installation

### Prerequisites

- AWS CLI installed and configured with appropriate permissions
- Python 3.9 or higher
- AWS account with administrator access
- Bash shell environment

### Deployment Steps

1. Run the preparation script to create all necessary files:

```bash
chmod +x prepare-ctf-infrastructure.sh
./prepare-ctf-infrastructure.sh
```

2. Deploy the CloudFormation template:

```bash
aws cloudformation deploy \
  --template-file cloudformation-template.yaml \
  --stack-name ctf-assessment-engine \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    ChallengeBucketName=$CHALLENGE_BUCKET \
    DeploymentBucketName=$DEPLOYMENT_BUCKET \
    ExternalId=$EXTERNAL_ID
```

3. Monitor the deployment progress in the AWS CloudFormation Console or using the AWS CLI:

```bash
aws cloudformation describe-stacks \
  --stack-name ctf-assessment-engine \
  --query 'Stacks[0].StackStatus'
```

4. Once the deployment is complete, retrieve the API endpoint URL:

```bash
aws cloudformation describe-stacks \
  --stack-name ctf-assessment-engine \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text
```

## Usage

### Creating a New Challenge

1. Create a directory for your challenge:

```bash
mkdir -p my-challenge
cd my-challenge
```

2. Create a `config.json` file with the challenge configuration:

```json
{
  "challengeId": "my-challenge",
  "name": "My Reliability Challenge",
  "description": "Improve the reliability of a system under load",
  "assessmentCriteria": [
    {
      "id": "multi-region",
      "name": "Multi-Region Deployment",
      "points": 10,
      "checkFunction": "check_multi_region_deployment"
    },
    {
      "id": "dynamodb-backup",
      "name": "DynamoDB Point-in-Time Recovery",
      "points": 10,
      "checkFunction": "check_dynamodb_backups"
    }
  ],
  "stackNamePrefix": "reliability-challenge-",
  "passingScore": 80
}
```

3. Create a `check-functions.py` file with assessment logic:

```python
def check_multi_region_deployment(participant_id, stack_name, credentials=None):
    import boto3
    
    # If credentials are provided, use them to create clients
    if credentials:
        session = boto3.Session(
            aws_access_key_id=credentials.get('aws_access_key_id'),
            aws_secret_access_key=credentials.get('aws_secret_access_key'),
            aws_session_token=credentials.get('aws_session_token')
        )
    else:
        session = boto3.Session()
    
    # Implementation details...
    
    return {
        "implemented": True,  # Replace with actual logic
        "details": {
            # Challenge-specific details
        }
    }

def check_dynamodb_backups(participant_id, stack_name, credentials=None):
    # Similar implementation...
    pass
```

4. Upload and register your challenge:

```bash
# Upload to S3
aws s3 cp config.json s3://$CHALLENGE_BUCKET/my-challenge/config.json
aws s3 cp check-functions.py s3://$CHALLENGE_BUCKET/my-challenge/check-functions.py

# Register in DynamoDB
aws dynamodb put-item \
  --table-name ctf-challenge-registry \
  --item '{
    "challengeId": {"S": "my-challenge"},
    "name": {"S": "My Reliability Challenge"},
    "description": {"S": "Improve the reliability of a system under load"},
    "s3Location": {"S": "s3://'$CHALLENGE_BUCKET'/my-challenge/"},
    "configFile": {"S": "config.json"},
    "checkFunctionsFile": {"S": "check-functions.py"},
    "difficulty": {"S": "intermediate"},
    "active": {"S": "true"},
    "createdBy": {"S": "admin"},
    "createdAt": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}
  }'
```

### Running an Assessment

To assess a participant's solution, make a POST request to the Assessment API:

```bash
curl -X POST \
  $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "participantId": "participant-123",
    "challengeId": "my-challenge",
    "teamId": "team-456"
  }'
```

The response will include a score, feedback, and details about implemented reliability features.

## Customization

### CloudFormation Parameters

The following parameters can be customized during deployment:

- **ChallengeBucketName**: Name of the S3 bucket that stores challenge definitions
- **DeploymentBucketName**: Name of the S3 bucket that stores Lambda deployment packages
- **ExternalId**: External ID for cross-account role assumption

### Lambda Environment Variables

The Assessment Engine Lambda function has the following environment variables:

- **CHALLENGE_REGISTRY_TABLE**: Name of the DynamoDB table for challenge registry
- **ASSESSMENT_RESULTS_TABLE**: Name of the DynamoDB table for assessment results
- **CHALLENGE_BUCKET**: Name of the S3 bucket that stores challenges
- **ASSESSMENT_ENGINE_EXTERNAL_ID**: External ID for cross-account role assumption

## Team Account Setup

For each team account, deploy the team account CloudFormation template:

```bash
aws cloudformation deploy \
  --template-file team-account-template.yaml \
  --stack-name ctf-assessment-engine-role \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    ManagementAccountId=$MANAGEMENT_ACCOUNT_ID \
    ExternalId=$EXTERNAL_ID \
  --profile team-account-profile
```

This creates an IAM role that allows the Assessment Engine to evaluate resources in the team account.

## Security Considerations

The implementation follows AWS security best practices:

- **Least Privilege Access**: IAM roles have minimal required permissions
- **Cross-Account Security**: External ID requirement prevents confused deputy problems
- **S3 Bucket Policies**: Restrict access to challenge and deployment buckets
- **DynamoDB Encryption**: Tables are encrypted at rest
- **Isolated Execution**: Each check function is loaded in isolation
- **Function Timeouts**: Prevent infinite loops and resource exhaustion
- **Input Validation**: Comprehensive validation of all inputs

## Monitoring and Operations

### CloudWatch Dashboard

The implementation includes a CloudWatch dashboard that displays:

- Average assessment scores
- Number of successful assessments
- Assessment duration
- Assessment errors

### CloudWatch Alarms

Two CloudWatch alarms are configured:

1. **AssessmentEngineErrors**: Triggers when there are too many assessment errors
2. **AssessmentEngineLambdaErrors**: Triggers when the Lambda function encounters errors

### SNS Topic

Alerts are sent to the `ctf-assessment-alerts` SNS topic, which can be subscribed to receive notifications via email, SMS, or other methods.

## Next Steps

After deploying the system, consider the following next steps:

1. **Create More Challenges**: Develop additional reliability challenges using the framework
2. **Enhance User Interface**: Build a web UI for participants and administrators
3. **Add Authentication**: Implement Cognito or another auth mechanism for the API
4. **Extend Metrics**: Create additional CloudWatch metrics and dashboards
5. **Scale Testing**: Run load tests to ensure the system can handle many participants

