#!/bin/bash
# prepare-ctf-infrastructure.sh
# This script prepares the environment for deploying the Dynamic Challenge Assessment Engine
# It creates the necessary JSON files, Lambda code, and other resources that will be referenced by CloudFormation

# Set up variables
export AWS_REGION=${AWS_REGION:-"us-east-1"}
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export CHALLENGE_BUCKET="ctf-reliability-challenges-$(date +%s)"
export DEPLOYMENT_BUCKET="ctf-deployment-$(date +%s)"
export EXTERNAL_ID="ctf-assessment-engine"
export WORKING_DIR="ctf-assessment-engine-files"

echo "Setting up infrastructure preparation for AWS Account: $ACCOUNT_ID"
echo "Challenge Bucket: $CHALLENGE_BUCKET"
echo "Deployment Bucket: $DEPLOYMENT_BUCKET"

# Create working directory
mkdir -p $WORKING_DIR
cd $WORKING_DIR

# Create IAM Trust Policy for Lambda
echo "Creating IAM trust policy..."
cat > assessment-engine-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM Policy for Lambda
echo "Creating IAM policy..."
cat > assessment-engine-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${CHALLENGE_BUCKET}",
        "arn:aws:s3:::${CHALLENGE_BUCKET}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:${AWS_REGION}:${ACCOUNT_ID}:table/ctf-challenge-registry",
        "arn:aws:dynamodb:${AWS_REGION}:${ACCOUNT_ID}:table/ctf-assessment-results",
        "arn:aws:dynamodb:${AWS_REGION}:${ACCOUNT_ID}:table/ctf-challenge-registry/index/*",
        "arn:aws:dynamodb:${AWS_REGION}:${ACCOUNT_ID}:table/ctf-assessment-results/index/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "arn:aws:iam::*:role/AssessmentEngineAccessRole"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:/aws/lambda/reliability-assessment-engine:*"
    }
  ]
}
EOF

# Create Lambda Function Code
echo "Creating Lambda function code..."
mkdir -p lambda-code
cat > lambda-code/index.py << 'EOF'
"""
Assessment Engine Lambda Function

This Lambda function is the core of the Dynamic Challenge Assessment Engine.
It loads challenge-specific check functions from S3 and executes them against
participant resources in team accounts.
"""

import json
import boto3
import logging
import importlib.util
import sys
import tempfile
import os
import time
import traceback
from datetime import datetime
import botocore.exceptions

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
sts = boto3.client('sts')
cloudwatch = boto3.client('cloudwatch')

def lambda_handler(event, context):
    """
    Main entry point for the Assessment Engine Lambda function.
    """
    start_time = time.time()
    
    # Extract parameters from the event
    try:
        participant_id = event.get('participantId')
        challenge_id = event.get('challengeId')
        team_id = event.get('teamId', 'default-team')
        
        if not participant_id or not challenge_id:
            raise ValueError("Missing required parameters: participantId and challengeId")
            
        logger.info(f"Starting assessment for participant {participant_id} on challenge {challenge_id}")
        
        # Load challenge configuration from DynamoDB
        challenge_config = load_challenge_config(challenge_id)
        logger.info(f"Loaded challenge configuration: {challenge_id}")
        
        # Dynamically load check functions from S3
        check_functions = load_check_functions_from_s3(
            challenge_config['s3Location'],
            challenge_config['checkFunctionsFile']
        )
        logger.info(f"Loaded check functions from S3: {challenge_config['checkFunctionsFile']}")
        
        # Identify the target account for assessment
        team_account_id = identify_team_account(team_id)
        logger.info(f"Identified team account: {team_account_id}")
        
        # Assume role in the participant account
        assumed_credentials = assume_assessment_role(team_account_id)
        logger.info(f"Assumed role in team account {team_account_id}")
        
        # Run the assessment with the loaded check functions
        assessment_results = run_assessment(
            participant_id,
            challenge_config,
            check_functions,
            assumed_credentials
        )
        logger.info(f"Completed assessment: {len(assessment_results)} criteria checked")
        
        # Calculate the total score
        score = calculate_score(assessment_results)
        passed = score >= challenge_config.get('passingScore', 80)
        
        # Generate feedback based on assessment results
        feedback = generate_feedback(assessment_results, score, passed)
        
        # Store results in DynamoDB
        store_assessment_results(
            participant_id,
            challenge_id,
            team_id,
            assessment_results,
            score,
            passed
        )
        logger.info(f"Stored assessment results. Score: {score}, Passed: {passed}")
        
        # Record metrics
        record_assessment_metrics(challenge_id, score, passed, time.time() - start_time)
        
        # Return results
        return {
            'participantId': participant_id,
            'challengeId': challenge_id,
            'teamId': team_id,
            'score': score,
            'maxScore': calculate_max_score(challenge_config),
            'passed': passed,
            'results': assessment_results,
            'feedback': feedback,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error during assessment: {str(e)}")
        logger.error(traceback.format_exc())
        
        # Record error metric
        try:
            cloudwatch.put_metric_data(
                Namespace='CTF/AssessmentEngine',
                MetricData=[
                    {
                        'MetricName': 'AssessmentErrors',
                        'Value': 1,
                        'Unit': 'Count',
                        'Dimensions': [
                            {
                                'Name': 'ChallengeId',
                                'Value': event.get('challengeId', 'unknown')
                            }
                        ]
                    }
                ]
            )
        except Exception as metric_error:
            logger.error(f"Failed to record error metric: {str(metric_error)}")
        
        raise

def load_challenge_config(challenge_id):
    """Load the challenge configuration from DynamoDB."""
    table = dynamodb.Table(os.environ.get('CHALLENGE_REGISTRY_TABLE', 'ctf-challenge-registry'))
    
    try:
        response = table.get_item(Key={'challengeId': challenge_id})
    except botocore.exceptions.ClientError as e:
        logger.error(f"DynamoDB error: {str(e)}")
        raise Exception(f"Failed to load challenge configuration: {str(e)}")
    
    if 'Item' not in response:
        raise Exception(f"Challenge not found: {challenge_id}")
    
    challenge = response['Item']
    
    # Check if the challenge is active
    if not challenge.get('active', 'true') == 'true':
        raise Exception(f"Challenge is not active: {challenge_id}")
    
    return challenge

def load_check_functions_from_s3(s3_location, check_functions_file):
    """Dynamically load check functions from an S3 object."""
    try:
        # Parse S3 location
        s3_path = s3_location.replace('s3://', '')
        parts = s3_path.split('/', 1)
        bucket_name = parts[0]
        key_prefix = parts[1] if len(parts) > 1 else ""
        
        # Get object from S3
        response = s3.get_object(
            Bucket=bucket_name,
            Key=f"{key_prefix}{check_functions_file}"
        )
        
        # Read code content
        code_content = response['Body'].read().decode('utf-8')
        
        # Create a temporary file to import as a module
        with tempfile.NamedTemporaryFile(suffix='.py', delete=False) as temp_file:
            temp_file_path = temp_file.name
            temp_file.write(code_content.encode('utf-8'))
        
        try:
            # Load the module using importlib
            module_name = f"check_functions_{int(time.time())}"
            spec = importlib.util.spec_from_file_location(module_name, temp_file_path)
            module = importlib.util.module_from_spec(spec)
            sys.modules[module_name] = module
            spec.loader.exec_module(module)
            
            return module
        finally:
            # Clean up the temporary file
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)
                
    except botocore.exceptions.ClientError as e:
        logger.error(f"S3 error: {str(e)}")
        raise Exception(f"Failed to load check functions from S3: {str(e)}")
    except Exception as e:
        logger.error(f"Error loading check functions: {str(e)}")
        logger.error(traceback.format_exc())
        raise Exception(f"Failed to load check functions: {str(e)}")

def identify_team_account(team_id):
    """Identify the AWS account ID for the team."""
    # In a real implementation, this would query a database or config
    team_account_mapping = json.loads(os.environ.get('TEAM_ACCOUNT_MAPPING', '{}'))
    
    if team_id in team_account_mapping:
        return team_account_mapping[team_id]
    
    # If no mapping found, return a default account ID from environment variable
    return os.environ.get('DEFAULT_TEAM_ACCOUNT_ID', '123456789012')

def assume_assessment_role(account_id):
    """Assume the AssessmentEngineAccessRole in the participant account."""
    try:
        role_arn = f"arn:aws:iam::{account_id}:role/AssessmentEngineAccessRole"
        external_id = os.environ.get('ASSESSMENT_ENGINE_EXTERNAL_ID', 'ctf-assessment-engine')
        
        logger.info(f"Assuming role: {role_arn} with external ID: {external_id}")
        
        response = sts.assume_role(
            RoleArn=role_arn,
            RoleSessionName="AssessmentEngineSession",
            ExternalId=external_id,
            DurationSeconds=900  # 15 minutes
        )
        
        return {
            'aws_access_key_id': response['Credentials']['AccessKeyId'],
            'aws_secret_access_key': response['Credentials']['SecretAccessKey'],
            'aws_session_token': response['Credentials']['SessionToken']
        }
    except botocore.exceptions.ClientError as e:
        logger.error(f"Error assuming role: {str(e)}")
        raise Exception(f"Failed to assume role in participant account: {str(e)}")

def run_assessment(participant_id, challenge_config, check_functions, assumed_credentials):
    """Execute the assessment using loaded check functions."""
    results = []
    stack_name_prefix = challenge_config.get('stackNamePrefix', 'reliability-challenge-')
    stack_name = f"{stack_name_prefix}{participant_id}"
    
    # Run each check function defined in the challenge config
    for criterion in challenge_config.get('assessmentCriteria', []):
        criterion_id = criterion.get('id')
        criterion_name = criterion.get('name')
        check_function_name = criterion.get('checkFunction')
        points = criterion.get('points', 0)
        
        logger.info(f"Checking criterion: {criterion_name} ({criterion_id}) using {check_function_name}")
        
        # Check if the function exists in the module
        if not hasattr(check_functions, check_function_name):
            logger.warning(f"Check function {check_function_name} not found in module")
            results.append({
                'criterionId': criterion_id,
                'name': criterion_name,
                'points': 0,
                'maxPoints': points,
                'implemented': False,
                'error': f"Check function not found: {check_function_name}"
            })
            continue
        
        try:
            # Get the check function
            check_function = getattr(check_functions, check_function_name)
            
            # Execute the check function with credentials for the participant account
            result = execute_check_function(
                check_function,
                participant_id,
                stack_name,
                assumed_credentials
            )
            
            # Add result to the list
            results.append({
                'criterionId': criterion_id,
                'name': criterion_name,
                'points': points if result.get('implemented', False) else 0,
                'maxPoints': points,
                'implemented': result.get('implemented', False),
                'details': result.get('details', {})
            })
            
            logger.info(f"Criterion {criterion_id} result: implemented={result.get('implemented', False)}")
            
        except Exception as e:
            logger.error(f"Error executing check function {check_function_name}: {str(e)}")
            logger.error(traceback.format_exc())
            
            results.append({
                'criterionId': criterion_id,
                'name': criterion_name,
                'points': 0,
                'maxPoints': points,
                'implemented': False,
                'error': str(e)
            })
    
    return results

def execute_check_function(check_function, participant_id, stack_name, credentials):
    """Execute a single check function with appropriate credentials."""
    try:
        # Set maximum execution time to prevent infinite loops
        import signal
        
        def timeout_handler(signum, frame):
            raise TimeoutError("Check function execution timed out")
        
        # Set timeout to 30 seconds
        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(30)
        
        # Execute the check function
        result = check_function(participant_id, stack_name, credentials)
        
        # Cancel the alarm
        signal.alarm(0)
        
        # Validate result format
        if not isinstance(result, dict):
            raise ValueError("Check function must return a dictionary")
        
        if 'implemented' not in result:
            raise ValueError("Check function result must include 'implemented' key")
        
        return result
    
    except Exception as e:
        logger.error(f"Error in check function execution: {str(e)}")
        raise

def calculate_score(assessment_results):
    """Calculate the total score based on assessment results."""
    return sum(result.get('points', 0) for result in assessment_results)

def calculate_max_score(challenge_config):
    """Calculate the maximum possible score for the challenge."""
    return sum(
        criterion.get('points', 0) 
        for criterion in challenge_config.get('assessmentCriteria', [])
    )

def generate_feedback(assessment_results, score, passed):
    """Generate feedback based on assessment results."""
    implemented = []
    suggestions = []
    
    for result in assessment_results:
        if result.get('implemented', False):
            implemented.append({
                'name': result.get('name'),
                'details': result.get('details', {})
            })
        else:
            suggestions.append({
                'name': result.get('name'),
                'points': result.get('maxPoints', 0)
            })
    
    # Generate summary message
    if passed:
        summary = f"Congratulations! You've successfully passed the challenge with a score of {score}."
    else:
        summary = f"You've scored {score} points, but need more improvements to pass the challenge."
        
    return {
        'summary': summary,
        'implemented': implemented,
        'suggestions': suggestions
    }

def store_assessment_results(participant_id, challenge_id, team_id, assessment_results, score, passed):
    """Store assessment results in DynamoDB."""
    table = dynamodb.Table(os.environ.get('ASSESSMENT_RESULTS_TABLE', 'ctf-assessment-results'))
    
    try:
        item = {
            'participantId': participant_id,
            'challengeId': challenge_id,
            'teamId': team_id,
            'timestamp': int(time.time() * 1000),  # Current time in milliseconds
            'score': score,
            'details': assessment_results,
            'passed': passed,
            'assessedAt': datetime.now().isoformat()
        }
        
        table.put_item(Item=item)
    except botocore.exceptions.ClientError as e:
        logger.error(f"DynamoDB error: {str(e)}")
        raise Exception(f"Failed to store assessment results: {str(e)}")

def record_assessment_metrics(challenge_id, score, passed, duration):
    """Record metrics about the assessment."""
    try:
        cloudwatch.put_metric_data(
            Namespace='CTF/AssessmentEngine',
            MetricData=[
                {
                    'MetricName': 'AssessmentScore',
                    'Value': score,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'ChallengeId',
                            'Value': challenge_id
                        }
                    ]
                },
                {
                    'MetricName': 'AssessmentsPassed',
                    'Value': 1 if passed else 0,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'ChallengeId',
                            'Value': challenge_id
                        }
                    ]
                },
                {
                    'MetricName': 'AssessmentDuration',
                    'Value': duration,
                    'Unit': 'Seconds',
                    'Dimensions': [
                        {
                            'Name': 'ChallengeId',
                            'Value': challenge_id
                        }
                    ]
                }
            ]
        )
    except Exception as e:
        logger.error(f"Failed to record metrics: {str(e)}")
        # Don't raise an exception, as this shouldn't fail the assessment
EOF

# Create Lambda requirements file
cat > lambda-code/requirements.txt << EOF
boto3==1.24.0
EOF

# Create a directory for the sample challenge
echo "Creating sample challenge files..."
mkdir -p sample-challenges/voting-system

# Create sample challenge config.json
cat > sample-challenges/voting-system/config.json << EOF
{
  "challengeId": "reliability-voting-system",
  "name": "Reliable Voting System",
  "description": "Improve a voting system's reliability during peak traffic",
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
    },
    {
      "id": "error-handling",
      "name": "Error Handling & Retry Logic",
      "points": 15,
      "checkFunction": "check_error_handling"
    }
  ],
  "stackNamePrefix": "reliability-challenge-",
  "passingScore": 80
}
EOF

# Create sample challenge check-functions.py
cat > sample-challenges/voting-system/check-functions.py << 'EOF'
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
    
    # Check for resources in multiple regions
    regions = ['us-east-1', 'us-west-2', 'eu-west-1']
    deployed_in_regions = []
    
    for region in regions:
        cf = session.client('cloudformation', region_name=region)
        try:
            stack = cf.describe_stacks(StackName=stack_name)
            if stack.get('Stacks'):
                deployed_in_regions.append(region)
        except Exception:
            # Stack doesn't exist in this region, continue
            pass
    
    # Check for global tables
    dynamodb = session.client('dynamodb')
    tables = dynamodb.list_tables()
    
    has_global_tables = False
    for table_name in tables.get('TableNames', []):
        if participant_id in table_name:
            try:
                table = dynamodb.describe_table(TableName=table_name)
                if 'GlobalTableVersion' in table.get('Table', {}):
                    has_global_tables = True
                    break
            except Exception as e:
                print(f"Error checking table {table_name}: {str(e)}")
    
    return {
        "implemented": len(deployed_in_regions) > 1 or has_global_tables,
        "details": {
            "regions": deployed_in_regions,
            "hasGlobalTables": has_global_tables
        }
    }

def check_dynamodb_backups(participant_id, stack_name, credentials=None):
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
    
    dynamodb = session.client('dynamodb')
    tables = dynamodb.list_tables()
    
    # Filter tables associated with the participant
    participant_tables = []
    for table_name in tables.get('TableNames', []):
        if participant_id in table_name or stack_name in table_name:
            participant_tables.append(table_name)
    
    # Check point-in-time recovery for each table
    tables_with_pitr = 0
    table_details = []
    
    for table_name in participant_tables:
        try:
            result = dynamodb.describe_continuous_backups(TableName=table_name)
            
            has_pitr = (
                result.get('ContinuousBackupsDescription', {})
                .get('PointInTimeRecoveryDescription', {})
                .get('PointInTimeRecoveryStatus') == 'ENABLED'
            )
            
            if has_pitr:
                tables_with_pitr += 1
            
            table_details.append({
                'tableName': table_name,
                'hasPITR': has_pitr
            })
        except Exception as e:
            print(f"Error checking PITR for table {table_name}: {str(e)}")
            table_details.append({
                'tableName': table_name,
                'hasPITR': False,
                'error': str(e)
            })
    
    return {
        "implemented": tables_with_pitr > 0 and tables_with_pitr == len(participant_tables),
        "details": {
            "tablesChecked": len(participant_tables),
            "tablesWithPITR": tables_with_pitr,
            "tableDetails": table_details
        }
    }

def check_error_handling(participant_id, stack_name, credentials=None):
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
    
    cf = session.client('cloudformation')
    lambda_client = session.client('lambda')
    
    # Get stack resources
    try:
        resources = cf.list_stack_resources(StackName=stack_name)
    except Exception:
        return {
            "implemented": False,
            "details": {
                "error": f"Stack {stack_name} not found"
            }
        }
    
    # Look for Lambda functions in the stack
    lambda_functions = []
    for resource in resources.get('StackResourceSummaries', []):
        if resource.get('ResourceType') == 'AWS::Lambda::Function':
            lambda_functions.append(resource.get('PhysicalResourceId'))
    
    # Check Lambda functions for error handling
    functions_with_dlq = 0
    functions_with_retries = 0
    function_details = []
    
    for function_name in lambda_functions:
        try:
            # Get Lambda function configuration
            function = lambda_client.get_function(FunctionName=function_name)
            function_config = function.get('Configuration', {})
            
            # Check for Dead Letter Queue
            has_dlq = 'DeadLetterConfig' in function_config and function_config['DeadLetterConfig'].get('TargetArn')
            
            # Check for retry attempts
            has_retries = False
            if 'Environment' in function_config:
                env_vars = function_config['Environment'].get('Variables', {})
                has_retries = 'MAX_RETRIES' in env_vars or 'RETRY_COUNT' in env_vars
            
            # Update counters
            if has_dlq:
                functions_with_dlq += 1
            if has_retries:
                functions_with_retries += 1
            
            function_details.append({
                'functionName': function_name,
                'hasDLQ': has_dlq,
                'hasRetries': has_retries
            })
        except Exception as e:
            print(f"Error checking function {function_name}: {str(e)}")
            function_details.append({
                'functionName': function_name,
                'error': str(e)
            })
    
    # Determine if error handling is implemented
    has_error_handling = (
        len(lambda_functions) > 0 and
        functions_with_dlq == len(lambda_functions) and
        functions_with_retries > 0
    )
    
    return {
        "implemented": has_error_handling,
        "details": {
            "functionsChecked": len(lambda_functions),
            "functionsWithDLQ": functions_with_dlq,
            "functionsWithRetries": functions_with_retries,
            "functionDetails": function_details
        }
    }
EOF

# Create CloudWatch Dashboard JSON file
echo "Creating CloudWatch dashboard configuration..."
cat > cloudwatch-dashboard.json << EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "CTF/AssessmentEngine", "AssessmentScore", "ChallengeId", "reliability-voting-system", { "stat": "Average" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Average Assessment Scores",
        "period": 300
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "CTF/AssessmentEngine", "AssessmentsPassed", "ChallengeId", "reliability-voting-system", { "stat": "Sum" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Successful Assessments",
        "period": 300
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "CTF/AssessmentEngine", "AssessmentDuration", "ChallengeId", "reliability-voting-system", { "stat": "Average" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Assessment Duration",
        "period": 300
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "CTF/AssessmentEngine", "AssessmentErrors", "ChallengeId", "reliability-voting-system", { "stat": "Sum" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Assessment Errors",
        "period": 300
      }
    }
  ]
}
EOF

# Create Team Account CloudFormation Template
echo "Creating team account CloudFormation template..."
cat > team-account-template.yaml << EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Cross-Account Role for CTF Assessment Engine'

Parameters:
  ManagementAccountId:
    Type: String
    Description: 'AWS Account ID of the Challenge Management Account'
  
  ExternalId:
    Type: String
    Description: 'External ID for cross-account role assumption'
    Default: 'ctf-assessment-engine'

Resources:
  AssessmentEngineAccessRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: AssessmentEngineAccessRole
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${ManagementAccountId}:role/AssessmentEngineRole'
            Action: sts:AssumeRole
            Condition:
              StringEquals:
                sts:ExternalId: !Ref ExternalId
      Policies:
        - PolicyName: AssessmentAccessPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - cloudformation:DescribeStacks
                  - cloudformation:ListStackResources
                  - cloudformation:DescribeStackResources
                Resource: '*'
              - Effect: Allow
                Action:
                  - dynamodb:DescribeTable
                  - dynamodb:Scan
                  - dynamodb:Query
                  - dynamodb:GetItem
                  - dynamodb:DescribeContinuousBackups
                Resource: '*'
              - Effect: Allow
                Action:
                  - lambda:ListFunctions
                  - lambda:GetFunction
                  - lambda:GetFunctionConfiguration
                Resource: '*'
              - Effect: Allow
                Action:
                  - ec2:DescribeRegions
                  - ec2:DescribeVpcs
                  - ec2:DescribeSubnets
                  - ec2:DescribeSecurityGroups
                Resource: '*'

Outputs:
  RoleArn:
    Description: 'ARN of the Assessment Engine Access Role'
    Value: !GetAtt AssessmentEngineAccessRole.Arn
EOF

# Create Test Participant Stack template
echo "Creating test participant stack template..."
cat > test-participant-stack.yaml << EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Test Participant Stack for CTF Challenge'

Resources:
  VotingTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: voting-system-test-participant
      BillingMode: PAY_PER_REQUEST
      KeySchema:
        - AttributeName: voteId
          KeyType: HASH
      AttributeDefinitions:
        - AttributeName: voteId
          AttributeType: S
      # Intentionally missing point-in-time recovery for testing

  VotingFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: voting-function-test-participant
      Handler: index.handler
      Runtime: python3.9
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          def handler(event, context):
              # Simple function without error handling or DLQ
              return {
                  'statusCode': 200,
                  'body': '{"message": "Vote recorded"}'
              }

  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

Outputs:
  TableName:
    Description: 'Name of the voting table'
    Value: !Ref VotingTable
  
  FunctionName:
    Description: 'Name of the voting function'
    Value: !Ref VotingFunction
EOF

# Create Lambda zip package
echo "Creating Lambda deployment package..."
cd lambda-code
pip install -r requirements.txt -t .
zip -r ../assessment-engine.zip .
cd ..

echo "Infrastructure preparation complete!"
echo "All necessary files have been created in the $WORKING_DIR directory."
echo ""
echo "Now you can deploy the CloudFormation template with the following command:"
echo "aws cloudformation deploy --template-file ctf-assessment-engine.yaml --stack-name ctf-assessment-engine --capabilities CAPABILITY_NAMED_IAM"
echo ""
echo "Environment variables to pass to CloudFormation:"
echo "CHALLENGE_BUCKET=$CHALLENGE_BUCKET"
echo "DEPLOYMENT_BUCKET=$DEPLOYMENT_BUCKET"
echo "EXTERNAL_ID=$EXTERNAL_ID"
