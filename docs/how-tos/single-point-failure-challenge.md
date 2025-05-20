# Implementing "The Single-Point Failure" Challenge for AWS Reliability CTF

This document provides a complete step-by-step implementation of "The Single-Point Failure" challenge for an AWS Reliability CTF event. This Beginner-level challenge focuses on high availability by having participants improve a single-region application to make it resilient against regional failures.

## Step 1: Define Learning Objectives

First, let's clearly establish what participants should learn from this challenge:

```
Learning objectives:
- Understand multi-region deployment strategies
- Implement cross-region data replication
- Configure disaster recovery mechanisms
- Set up health checks and routing policies
- Design for region failover without data loss
- Implement proper monitoring for multi-region applications
```

## Step 2: Design the Challenge Scenario

Now, let's create a compelling scenario for the challenge:

```
Scenario: "The Single-Point Failure"

You've been hired as a reliability engineer for GlobalVote Inc., a company that provides voting services for online contests and elections. Their flagship application, "QuickPoll," has been gaining popularity, but last month they experienced a complete outage when AWS had service issues in their primary region.

The CEO has tasked you with making the application resilient against regional failures to prevent future outages. Currently, the entire application (web frontend, API layer, and database) is deployed in a single AWS region with no redundancy.

Your mission is to redesign and implement multi-region redundancy for the application while ensuring data consistency and minimal disruption during regional failures.
```

## Step 3: Documenting Current (Unreliable) Architecture

Let's document the current architecture with its reliability issues:

```
Current Architecture (Unreliable):

- Single-region deployment in us-east-1
- Frontend: Single S3 bucket with CloudFront distribution
- API: Lambda functions without cross-region redundancy
- Database: DynamoDB table without global tables
- Route 53 health checks not implemented
- No failover routing policies configured
- No cross-region monitoring or alerting

Known issues:
- Complete system unavailability during regional outages
- No data replication across regions
- No automatic failover mechanism
- Lack of health checks to detect regional failures
- Missing cross-region monitoring and alerting
```

## Step 4: Documenting Target (Reliable) Architecture

Now let's define the target architecture that would resolve all reliability issues:

```
Target Architecture (Reliable):

- Multi-region deployment across us-east-1 and us-west-2
- Frontend: Multiple S3 buckets with CloudFront distribution using origin failover
- API: Lambda functions deployed in multiple regions
- Database: DynamoDB global tables for multi-region data replication
- Route 53 health checks monitoring each region's availability
- Route 53 failover routing policies for automatic traffic redirection
- CloudWatch cross-region dashboards and alarms

Reliability improvements:
[10 pts] Multi-region frontend deployment
[15 pts] DynamoDB global tables implementation
[15 pts] Lambda functions deployed across multiple regions
[10 pts] Route 53 health checks configuration
[15 pts] Route 53 failover routing policies
[10 pts] Cross-region monitoring and alerting
[10 pts] CloudFront origin failover configuration
[15 pts] End-to-end failover testing and validation
```

## Step 5: Implementation with CloudFormation

### Base Template (Unreliable Application)

Let's create a Python script to generate the unreliable CloudFormation template:

```python
#!/usr/bin/env python3
# generate_unreliable_template.py

import json
import boto3
import uuid

def generate_unreliable_template(participant_id):
    """Generate the unreliable base CloudFormation template for the challenge."""
    
    template = {
        "AWSTemplateFormatVersion": "2010-09-09",
        "Description": "CTF Challenge - The Single-Point Failure (Unreliable Starting Point)",
        "Parameters": {
            "ParticipantId": {
                "Type": "String",
                "Default": participant_id,
                "Description": "Unique identifier for the participant"
            }
        },
        "Resources": {
            # DynamoDB Table (without global tables)
            "PollsTable": {
                "Type": "AWS::DynamoDB::Table",
                "Properties": {
                    "TableName": f"quickpoll-{participant_id}",
                    "BillingMode": "PAY_PER_REQUEST",
                    "KeySchema": [
                        {"AttributeName": "pollId", "KeyType": "HASH"},
                        {"AttributeName": "timestamp", "KeyType": "RANGE"}
                    ],
                    "AttributeDefinitions": [
                        {"AttributeName": "pollId", "AttributeType": "S"},
                        {"AttributeName": "timestamp", "AttributeType": "N"}
                    ],
                    # Missing: Point-in-time recovery
                    # Missing: Global table configuration
                }
            },
            
            # S3 Bucket for Website (single region)
            "WebsiteBucket": {
                "Type": "AWS::S3::Bucket",
                "Properties": {
                    "BucketName": f"quickpoll-website-{participant_id}",
                    "WebsiteConfiguration": {
                        "IndexDocument": "index.html",
                        "ErrorDocument": "error.html"
                    },
                    # Missing: Cross-region replication
                }
            },
            
            # S3 Bucket Policy
            "BucketPolicy": {
                "Type": "AWS::S3::BucketPolicy",
                "Properties": {
                    "Bucket": {"Ref": "WebsiteBucket"},
                    "PolicyDocument": {
                        "Version": "2012-10-17",
                        "Statement": [
                            {
                                "Effect": "Allow",
                                "Principal": "*",
                                "Action": "s3:GetObject",
                                "Resource": {"Fn::Join": ["", [
                                    "arn:aws:s3:::", {"Ref": "WebsiteBucket"}, "/*"
                                ]]}
                            }
                        ]
                    }
                }
            },
            
            # CloudFront Distribution (without origin failover)
            "CloudFrontDistribution": {
                "Type": "AWS::CloudFront::Distribution",
                "Properties": {
                    "DistributionConfig": {
                        "Origins": [
                            {
                                "DomainName": {"Fn::GetAtt": ["WebsiteBucket", "DomainName"]},
                                "Id": "S3Origin",
                                "S3OriginConfig": {
                                    "OriginAccessIdentity": ""
                                }
                            }
                        ],
                        "Enabled": True,
                        "DefaultRootObject": "index.html",
                        "DefaultCacheBehavior": {
                            "TargetOriginId": "S3Origin",
                            "ViewerProtocolPolicy": "redirect-to-https",
                            "ForwardedValues": {
                                "QueryString": False,
                                "Cookies": {"Forward": "none"}
                            }
                        },
                        # Missing: Origin failover configuration
                    }
                }
            },
            
            # IAM Role for Lambda
            "PollLambdaRole": {
                "Type": "AWS::IAM::Role",
                "Properties": {
                    "AssumeRolePolicyDocument": {
                        "Version": "2012-10-17",
                        "Statement": [
                            {
                                "Effect": "Allow",
                                "Principal": {"Service": "lambda.amazonaws.com"},
                                "Action": "sts:AssumeRole"
                            }
                        ]
                    },
                    "ManagedPolicyArns": [
                        "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
                    ],
                    "Policies": [
                        {
                            "PolicyName": "DynamoDBAccess",
                            "PolicyDocument": {
                                "Version": "2012-10-17",
                                "Statement": [
                                    {
                                        "Effect": "Allow",
                                        "Action": [
                                            "dynamodb:GetItem",
                                            "dynamodb:PutItem",
                                            "dynamodb:UpdateItem",
                                            "dynamodb:Query",
                                            "dynamodb:Scan"
                                        ],
                                        "Resource": {"Fn::GetAtt": ["PollsTable", "Arn"]}
                                    }
                                ]
                            }
                        }
                    ]
                }
            },
            
            # Lambda Functions (single region)
            "CreatePollFunction": {
                "Type": "AWS::Lambda::Function",
                "Properties": {
                    "FunctionName": f"quickpoll-create-{participant_id}",
                    "Handler": "index.handler",
                    "Role": {"Fn::GetAtt": ["PollLambdaRole", "Arn"]},
                    "Runtime": "python3.9",
                    "Timeout": 10,
                    "Environment": {
                        "Variables": {
                            "TABLE_NAME": {"Ref": "PollsTable"}
                        }
                    },
                    "Code": {
                        "ZipFile": """
import json
import boto3
import time
import os
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def handler(event, context):
    try:
        # Parse request body
        body = json.loads(event['body']) if event.get('body') else {}
        
        # Generate unique ID for the poll
        poll_id = str(uuid.uuid4())
        timestamp = int(time.time())
        
        # Store poll in DynamoDB
        item = {
            'pollId': poll_id,
            'timestamp': timestamp,
            'question': body.get('question', ''),
            'options': body.get('options', []),
            'votes': {option: 0 for option in body.get('options', [])}
        }
        
        table.put_item(Item=item)
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'pollId': poll_id})
        }
    except Exception as e:
        print(f"Error creating poll: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Failed to create poll'})
        }
"""
                    }
                }
            },
            
            "GetPollFunction": {
                "Type": "AWS::Lambda::Function",
                "Properties": {
                    "FunctionName": f"quickpoll-get-{participant_id}",
                    "Handler": "index.handler",
                    "Role": {"Fn::GetAtt": ["PollLambdaRole", "Arn"]},
                    "Runtime": "python3.9",
                    "Timeout": 10,
                    "Environment": {
                        "Variables": {
                            "TABLE_NAME": {"Ref": "PollsTable"}
                        }
                    },
                    "Code": {
                        "ZipFile": """
import json
import boto3
import os
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def handler(event, context):
    try:
        # Get poll ID from path parameters
        poll_id = event['pathParameters']['pollId']
        
        # Query DynamoDB for the poll
        response = table.query(
            KeyConditionExpression=Key('pollId').eq(poll_id),
            ScanIndexForward=False,
            Limit=1
        )
        
        if not response['Items']:
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Poll not found'})
            }
        
        poll = response['Items'][0]
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(poll)
        }
    except Exception as e:
        print(f"Error getting poll: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Failed to get poll'})
        }
"""
                    }
                }
            },
            
            "VoteFunction": {
                "Type": "AWS::Lambda::Function",
                "Properties": {
                    "FunctionName": f"quickpoll-vote-{participant_id}",
                    "Handler": "index.handler",
                    "Role": {"Fn::GetAtt": ["PollLambdaRole", "Arn"]},
                    "Runtime": "python3.9",
                    "Timeout": 10,
                    "Environment": {
                        "Variables": {
                            "TABLE_NAME": {"Ref": "PollsTable"}
                        }
                    },
                    "Code": {
                        "ZipFile": """
import json
import boto3
import os
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def handler(event, context):
    try:
        # Get poll ID from path parameters
        poll_id = event['pathParameters']['pollId']
        
        # Parse request body to get selected option
        body = json.loads(event['body']) if event.get('body') else {}
        option = body.get('option')
        
        if not option:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Option is required'})
            }
        
        # Query DynamoDB for the poll
        response = table.query(
            KeyConditionExpression=Key('pollId').eq(poll_id),
            ScanIndexForward=False,
            Limit=1
        )
        
        if not response['Items']:
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Poll not found'})
            }
        
        poll = response['Items'][0]
        
        # Check if option is valid
        if option not in poll['options']:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid option'})
            }
        
        # Update vote count
        table.update_item(
            Key={
                'pollId': poll_id,
                'timestamp': poll['timestamp']
            },
            UpdateExpression="ADD votes.#option :val",
            ExpressionAttributeNames={
                '#option': option
            },
            ExpressionAttributeValues={
                ':val': 1
            }
        )
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'success': True})
        }
    except Exception as e:
        print(f"Error voting: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Failed to record vote'})
        }
"""
                    }
                }
            },
            
            # API Gateway (single region)
            "PollsApi": {
                "Type": "AWS::ApiGateway::RestApi",
                "Properties": {
                    "Name": f"quickpoll-api-{participant_id}",
                    "Description": "API for QuickPoll application"
                }
            },
            
            # API Resources and Methods
            "PollsResource": {
                "Type": "AWS::ApiGateway::Resource",
                "Properties": {
                    "RestApiId": {"Ref": "PollsApi"},
                    "ParentId": {"Fn::GetAtt": ["PollsApi", "RootResourceId"]},
                    "PathPart": "polls"
                }
            },
            
            "CreatePollMethod": {
                "Type": "AWS::ApiGateway::Method",
                "Properties": {
                    "RestApiId": {"Ref": "PollsApi"},
                    "ResourceId": {"Ref": "PollsResource"},
                    "HttpMethod": "POST",
                    "AuthorizationType": "NONE",
                    "Integration": {
                        "Type": "AWS_PROXY",
                        "IntegrationHttpMethod": "POST",
                        "Uri": {"Fn::Sub": "arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${CreatePollFunction.Arn}/invocations"}
                    }
                }
            },
            
            "PollResource": {
                "Type": "AWS::ApiGateway::Resource",
                "Properties": {
                    "RestApiId": {"Ref": "PollsApi"},
                    "ParentId": {"Ref": "PollsResource"},
                    "PathPart": "{pollId}"
                }
            },
            
            "GetPollMethod": {
                "Type": "AWS::ApiGateway::Method",
                "Properties": {
                    "RestApiId": {"Ref": "PollsApi"},
                    "ResourceId": {"Ref": "PollResource"},
                    "HttpMethod": "GET",
                    "AuthorizationType": "NONE",
                    "Integration": {
                        "Type": "AWS_PROXY",
                        "IntegrationHttpMethod": "POST",
                        "Uri": {"Fn::Sub": "arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${GetPollFunction.Arn}/invocations"}
                    }
                }
            },
            
            "VoteMethod": {
                "Type": "AWS::ApiGateway::Method",
                "Properties": {
                    "RestApiId": {"Ref": "PollsApi"},
                    "ResourceId": {"Ref": "PollResource"},
                    "HttpMethod": "POST",
                    "AuthorizationType": "NONE",
                    "Integration": {
                        "Type": "AWS_PROXY",
                        "IntegrationHttpMethod": "POST",
                        "Uri": {"Fn::Sub": "arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${VoteFunction.Arn}/invocations"}
                    }
                }
            },
            
            # API Deployment
            "ApiDeployment": {
                "Type": "AWS::ApiGateway::Deployment",
                "DependsOn": ["CreatePollMethod", "GetPollMethod", "VoteMethod"],
                "Properties": {
                    "RestApiId": {"Ref": "PollsApi"},
                    "StageName": "prod"
                }
            },
            
            # Lambda Permissions
            "CreatePollPermission": {
                "Type": "AWS::Lambda::Permission",
                "Properties": {
                    "Action": "lambda:InvokeFunction",
                    "FunctionName": {"Ref": "CreatePollFunction"},
                    "Principal": "apigateway.amazonaws.com",
                    "SourceArn": {"Fn::Sub": "arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${PollsApi}/*/POST/polls"}
                }
            },
            
            "GetPollPermission": {
                "Type": "AWS::Lambda::Permission",
                "Properties": {
                    "Action": "lambda:InvokeFunction",
                    "FunctionName": {"Ref": "GetPollFunction"},
                    "Principal": "apigateway.amazonaws.com",
                    "SourceArn": {"Fn::Sub": "arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${PollsApi}/*/GET/polls/*"}
                }
            },
            
            "VotePermission": {
                "Type": "AWS::Lambda::Permission",
                "Properties": {
                    "Action": "lambda:InvokeFunction",
                    "FunctionName": {"Ref": "VoteFunction"},
                    "Principal": "apigateway.amazonaws.com",
                    "SourceArn": {"Fn::Sub": "arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${PollsApi}/*/POST/polls/*"}
                }
            }
            
            # Missing: Health checks
            # Missing: Multi-region resources
            # Missing: Failover routing policies
        },
        
        "Outputs": {
            "ApiEndpoint": {
                "Description": "URL of the API endpoint",
                "Value": {"Fn::Sub": "https://${PollsApi}.execute-api.${AWS::Region}.amazonaws.com/prod"}
            },
            "WebsiteURL": {
                "Description": "URL of the S3 website",
                "Value": {"Fn::GetAtt": ["WebsiteBucket", "WebsiteURL"]}
            },
            "CloudFrontURL": {
                "Description": "URL of the CloudFront distribution",
                "Value": {"Fn::Sub": "https://${CloudFrontDistribution.DomainName}"}
            }
        }
    }
    
    return template

def save_template(participant_id):
    """Save the generated template to a file"""
    template = generate_unreliable_template(participant_id)
    
    filename = f"unreliable-app-template-{participant_id}.json"
    with open(filename, "w") as f:
        json.dump(template, f, indent=2)
    
    print(f"Template saved to {filename}")
    return filename

if __name__ == "__main__":
    # Generate a unique participant ID or use a provided one
    import sys
    participant_id = sys.argv[1] if len(sys.argv) > 1 else f"participant-{uuid.uuid4().hex[:8]}"
    
    save_template(participant_id)
```

### Deployment Script

Now, let's create a deployment script to deploy the challenge for each participant:

```python
#!/usr/bin/env python3
# deploy_challenge.py

import boto3
import uuid
import subprocess
import sys
import json
import time
import os
import tempfile
from generate_unreliable_template import generate_unreliable_template, save_template

def deploy_for_participant(participant_id, region="us-east-1"):
    """Deploy a unique instance for each participant"""
    print(f"Deploying for participant: {participant_id}")
    
    # Generate template
    template_file = save_template(participant_id)
    
    # Create stack name with participant ID
    stack_name = f"single-point-failure-{participant_id}"
    
    # Deploy CloudFormation template with participant-specific parameters
    cmd = [
        "aws", "cloudformation", "deploy",
        "--template-file", template_file,
        "--stack-name", stack_name,
        "--parameter-overrides", f"ParticipantId={participant_id}",
        "--capabilities", "CAPABILITY_NAMED_IAM",
        "--region", region
    ]
    
    try:
        subprocess.run(cmd, check=True)
        print(f"Deployment complete: {stack_name}")
        
        # Get stack outputs for verification
        cloudformation = boto3.client('cloudformation', region_name=region)
        response = cloudformation.describe_stacks(StackName=stack_name)
        outputs = response['Stacks'][0]['Outputs']
        
        output_dict = {}
        for output in outputs:
            output_dict[output['OutputKey']] = output['OutputValue']
        
        print("Application URLs:")
        print(f"API Endpoint: {output_dict.get('ApiEndpoint')}")
        print(f"Website URL: {output_dict.get('WebsiteURL')}")
        print(f"CloudFront URL: {output_dict.get('CloudFrontURL')}")
        
        # Upload sample website content to S3
        upload_sample_website(participant_id, output_dict.get('CloudFrontURL'))
        
        return stack_name, output_dict
    
    except subprocess.CalledProcessError as e:
        print(f"Deployment failed: {e}")
        raise

def upload_sample_website(participant_id, cloudfront_url):
    """Upload sample website content to S3 bucket"""
    # Create sample HTML content
    index_html = f"""<!DOCTYPE html>
<html>
<head>
    <title>QuickPoll - Create and Share Polls</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 0; padding: 20px; }}
        .container {{ max-width: 800px; margin: 0 auto; }}
        h1 {{ color: #333; }}
        .poll-form {{ background: #f5f5f5; padding: 20px; border-radius: 5px; margin-top: 20px; }}
        label {{ display: block; margin-bottom: 5px; }}
        input, textarea {{ width: 100%; padding: 8px; margin-bottom: 15px; }}
        button {{ background: #4CAF50; color: white; border: none; padding: 10px 15px; cursor: pointer; }}
        #options-container {{ margin-bottom: 15px; }}
        .option {{ margin-bottom: 5px; }}
        .add-option {{ background: #2196F3; }}
        #message {{ margin-top: 20px; padding: 10px; display: none; }}
        .success {{ background: #dff0d8; color: #3c763d; }}
        .error {{ background: #f2dede; color: #a94442; }}
        .hidden {{ display: none; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>QuickPoll</h1>
        <p>Create and share polls quickly and easily!</p>
        
        <div id="create-poll" class="poll-form">
            <h2>Create a New Poll</h2>
            <form id="poll-form">
                <label for="question">Question:</label>
                <input type="text" id="question" required>
                
                <label>Options:</label>
                <div id="options-container">
                    <div class="option">
                        <input type="text" class="option-input" required>
                    </div>
                    <div class="option">
                        <input type="text" class="option-input" required>
                    </div>
                </div>
                
                <button type="button" class="add-option" id="add-option">Add Another Option</button>
                <button type="submit">Create Poll</button>
            </form>
        </div>
        
        <div id="poll-created" class="poll-form hidden">
            <h2>Poll Created!</h2>
            <p>Your poll has been created. Share this link with others:</p>
            <input type="text" id="poll-link" readonly>
            <button id="copy-link">Copy Link</button>
            <button id="create-another">Create Another Poll</button>
        </div>
        
        <div id="message"></div>
    </div>
    
    <script>
        // API endpoint (this will be replaced with the actual endpoint)
        const API_URL = '{cloudfront_url}';
        
        document.addEventListener('DOMContentLoaded', function() {
            const addOptionBtn = document.getElementById('add-option');
            const optionsContainer = document.getElementById('options-container');
            const pollForm = document.getElementById('poll-form');
            const createPollDiv = document.getElementById('create-poll');
            const pollCreatedDiv = document.getElementById('poll-created');
            const pollLinkInput = document.getElementById('poll-link');
            const copyLinkBtn = document.getElementById('copy-link');
            const createAnotherBtn = document.getElementById('create-another');
            const messageDiv = document.getElementById('message');
            
            // Add option button
            addOptionBtn.addEventListener('click', function() {
                const optionDiv = document.createElement('div');
                optionDiv.className = 'option';
                optionDiv.innerHTML = '<input type="text" class="option-input" required>';
                optionsContainer.appendChild(optionDiv);
            });
            
            // Form submission
            pollForm.addEventListener('submit', function(e) {
                e.preventDefault();
                
                const question = document.getElementById('question').value;
                const optionInputs = document.querySelectorAll('.option-input');
                const options = [];
                
                optionInputs.forEach(input => {
                    if (input.value.trim()) {
                        options.push(input.value.trim());
                    }
                });
                
                if (options.length < 2) {
                    showMessage('Please provide at least two options.', 'error');
                    return;
                }
                
                // Create poll
                createPoll(question, options);
            });
            
            // Copy link button
            copyLinkBtn.addEventListener('click', function() {
                pollLinkInput.select();
                document.execCommand('copy');
                showMessage('Link copied to clipboard!', 'success');
            });
            
            // Create another poll button
            createAnotherBtn.addEventListener('click', function() {
                pollForm.reset();
                createPollDiv.classList.remove('hidden');
                pollCreatedDiv.classList.add('hidden');
            });
            
            // Function to create a poll
            function createPoll(question, options) {
                // For now, just simulate API call
                console.log('Creating poll:', {{ question, options }});
                
                // Show success message
                createPollDiv.classList.add('hidden');
                pollCreatedDiv.classList.remove('hidden');
                
                // Generate a fake poll link (this would normally come from the API)
                const pollId = Math.random().toString(36).substring(2, 10);
                const pollLink = `${{window.location.origin}}/poll.html?id=${{pollId}}`;
                pollLinkInput.value = pollLink;
                
                showMessage('Poll created successfully!', 'success');
            }
            
            // Function to show messages
            function showMessage(text, type) {
                messageDiv.textContent = text;
                messageDiv.className = type;
                messageDiv.style.display = 'block';
                
                setTimeout(() => {
                    messageDiv.style.display = 'none';
                }, 5000);
            }
        });
    </script>
</body>
</html>
"""
    
    error_html = """<!DOCTYPE html>
<html>
<head>
    <title>Error - QuickPoll</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; text-align: center; }
        .container { max-width: 600px; margin: 100px auto; }
        h1 { color: #d9534f; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Oops! Something went wrong</h1>
        <p>Sorry, the page you're looking for cannot be found or an error occurred.</p>
        <p><a href="index.html">Return to Homepage</a></p>
    </div>
</body>
</html>
"""
    
    # Create temporary files
    import tempfile
    import os
    
    with tempfile.NamedTemporaryFile(suffix='.html', delete=False) as index_file:
        index_file.write(index_html.encode('utf-8'))
        index_file_path = index_file.name
    
    with tempfile.NamedTemporaryFile(suffix='.html', delete=False) as error_file:
        error_file.write(error_html.encode('utf-8'))
        error_file_path = error_file.name
    
    try:
        # Upload files to S3
        s3 = boto3.client('s3')
        bucket_name = f"quickpoll-website-{participant_id}"
        
        # Upload index.html
        s3.upload_file(
            index_file_path, 
            bucket_name, 
            'index.html',
            ExtraArgs={'ContentType': 'text/html'}
        )
        
        # Upload error.html
        s3.upload_file(
            error_file_path, 
            bucket_name, 
            'error.html',
            ExtraArgs={'ContentType': 'text/html'}
        )
        
        print(f"Sample website content uploaded to bucket: {bucket_name}")
    
    except Exception as e:
        print(f"Error uploading website content: {e}")
    
    finally:
        # Clean up temporary files
        os.unlink(index_file_path)
        os.unlink(error_file_path)

# Usage
if __name__ == "__main__":
    # Use command-line arg or generate a random ID
    participant_id = sys.argv[1] if len(sys.argv) > 1 else f"participant-{uuid.uuid4().hex[:8]}"
    region = sys.argv[2] if len(sys.argv) > 2 else "us-east-1"
    
    try:
        stack_name, outputs = deploy_for_participant(participant_id, region)
        print(f"Challenge deployed successfully for participant: {participant_id}")
        print(f"Stack: {stack_name}")
    except Exception as err:
        print(f"Deployment failed: {err}")
        sys.exit(1)
```

## Step 6: Create Check Functions for Assessment

Let's implement the check functions that will assess the participant's solution:

```python
# challenge_specific_checks.py

import boto3
import json
from botocore.exceptions import ClientError

async def check_multi_region_frontend_deployment(participant_id, stack_name, credentials=None):
    """
    Check if the participant has implemented a multi-region frontend deployment.
    
    Args:
        participant_id: The unique identifier for the participant
        stack_name: The CloudFormation stack name
        credentials: Optional AWS credentials for cross-account access
        
    Returns:
        dict: Assessment result with implementation status and details
    """
    # Create boto3 session with optional credentials
    if credentials:
        session = boto3.Session(
            aws_access_key_id=credentials.get('aws_access_key_id'),
            aws_secret_access_key=credentials.get('aws_secret_access_key'),
            aws_session_token=credentials.get('aws_session_token')
        )
    else:
        session = boto3.Session()
    
    # Check for S3 buckets in multiple regions
    s3_client = session.client('s3')
    cloudfront_client = session.client('cloudfront')
    
    try:
        # List all buckets
        response = s3_client.list_buckets()
        participant_buckets = [
            bucket for bucket in response['Buckets'] 
            if f"quickpoll-website-{participant_id}" in bucket['Name']
        ]
        
        # Check bucket locations
        bucket_regions = []
        for bucket in participant_buckets:
            try:
                location = s3_client.get_bucket_location(Bucket=bucket['Name'])
                region = location['LocationConstraint']
                # Note: us-east-1 returns None as LocationConstraint
                region = 'us-east-1' if region is None else region
                bucket_regions.append(region)
            except Exception as e:
                print(f"Error getting bucket location: {e}")
        
        # Check if there are buckets in multiple regions
        unique_regions = set(bucket_regions)
        multiple_regions = len(unique_regions) > 1
        
        # Check CloudFront configuration for origin failover
        has_origin_failover = False
        cloudfront_with_failover = []
        
        # List CloudFront distributions
        distributions = cloudfront_client.list_distributions().get('DistributionList', {}).get('Items', [])
        
        for dist in distributions:
            # Check if this distribution belongs to the participant
            if participant_id in dist.get('Comment', ''):
                # Check for origin groups (failover configuration)
                origin_groups = dist.get('OriginGroups', {}).get('Quantity', 0)
                if origin_groups > 0:
                    has_origin_failover = True
                    cloudfront_with_failover.append(dist['Id'])
        
        # Determine if multi-region frontend is implemented
        multi_region_frontend = multiple_regions and has_origin_failover
        
        return {
            "implemented": multi_region_frontend,
            "details": {
                "bucket_regions": list(unique_regions),
                "multiple_regions": multiple_regions,
                "has_origin_failover": has_origin_failover,
                "cloudfront_with_failover": cloudfront_with_failover
            }
        }
    
    except Exception as e:
        print(f"Error checking multi-region frontend: {e}")
        return {
            "implemented": False,
            "details": {
                "error": str(e)
            }
        }

async def check_dynamodb_global_tables(participant_id, stack_name, credentials=None):
    """
    Check if the participant has implemented DynamoDB global tables.
    
    Args:
        participant_id: The unique identifier for the participant
        stack_name: The CloudFormation stack name
        credentials: Optional AWS credentials for cross-account access
        
    Returns:
        dict: Assessment result with implementation status and details
    """
    # Create boto3 session with optional credentials
    if credentials:
        session = boto3.Session(
            aws_access_key_id=credentials.get('aws_access_key_id'),
            aws_secret_access_key=credentials.get('aws_secret_access_key'),
            aws_session_token=credentials.get('aws_session_token')
        )
    else:
        session = boto3.Session()
    
    dynamodb_client = session.client('dynamodb')
    
    try:
        # Find tables associated with this participant
        response = dynamodb_client.list_tables()
        participant_tables = [
            table for table in response['TableNames']
            if f"quickpoll-{participant_id}" in table
        ]
        
        # Check if any table is a global table
        global_tables = []
        regions_per_table = {}
        
        for table_name in participant_tables:
            try:
                # First check if it's a global table by describing it
                table_desc = dynamodb_client.describe_table(TableName=table_name)
                
                # Next, try to describe global table
                try:
                    global_desc = dynamodb_client.describe_global_table(GlobalTableName=table_name)
                    is_global = True
                    replicas = [
                        replica['RegionName'] 
                        for replica in global_desc.get('GlobalTableDescription', {}).get('ReplicationGroup', [])
                    ]
                    global_tables.append(table_name)
                    regions_per_table[table_name] = replicas
                except ClientError:
                    # Check using ListGlobalTables as fallback
                    try:
                        all_global_tables = dynamodb_client.list_global_tables()
                        is_global = table_name in [
                            t['GlobalTableName'] 
                            for t in all_global_tables.get('GlobalTables', [])
                        ]
                        if is_global:
                            global_tables.append(table_name)
                    except:
                        is_global = False
            except Exception as e:
                print(f"Error checking table {table_name}: {e}")
        
        # Check if tables have point-in-time recovery enabled
        tables_with_pitr = []
        for table_name in participant_tables:
            try:
                backup_desc = dynamodb_client.describe_continuous_backups(TableName=table_name)
                has_pitr = (
                    backup_desc.get('ContinuousBackupsDescription', {})
                    .get('PointInTimeRecoveryDescription', {})
                    .get('PointInTimeRecoveryStatus') == 'ENABLED'
                )
                if has_pitr:
                    tables_with_pitr.append(table_name)
            except Exception as e:
                print(f"Error checking PITR for table {table_name}: {e}")
        
        # Determine if DynamoDB global tables are implemented
        has_global_tables = len(global_tables) > 0
        has_pitr = len(tables_with_pitr) > 0 and len(tables_with_pitr) == len(participant_tables)
        
        return {
            "implemented": has_global_tables and has_pitr,
            "details": {
                "global_tables": global_tables,
                "regions_per_table": regions_per_table,
                "has_pitr": has_pitr,
                "tables_with_pitr": tables_with_pitr,
                "tables_checked": participant_tables
            }
        }
    
    except Exception as e:
        print(f"Error checking DynamoDB global tables: {e}")
        return {
            "implemented": False,
            "details": {
                "error": str(e)
            }
        }

async def check_multi_region_lambda_deployment(participant_id, stack_name, credentials=None):
    """
    Check if the participant has deployed Lambda functions in multiple regions.
    
    Args:
        participant_id: The unique identifier for the participant
        stack_name: The CloudFormation stack name
        credentials: Optional AWS credentials for cross-account access
        
    Returns:
        dict: Assessment result with implementation status and details
    """
    # Create boto3 session with optional credentials
    if credentials:
        session = boto3.Session(
            aws_access_key_id=credentials.get('aws_access_key_id'),
            aws_secret_access_key=credentials.get('aws_secret_access_key'),
            aws_session_token=credentials.get('aws_session_token')
        )
    else:
        session = boto3.Session()
    
    # Regions to check
    regions = ['us-east-1', 'us-west-2', 'eu-west-1', 'ap-northeast-1']
    
    lambda_regions = {}
    api_gateway_regions = {}
    
    # Check each region for Lambda functions and API Gateway APIs
    for region in regions:
        lambda_client = session.client('lambda', region_name=region)
        apigw_client = session.client('apigateway', region_name=region)
        
        try:
            # Check for Lambda functions
            lambda_functions = []
            response = lambda_client.list_functions()
            
            for function in response.get('Functions', []):
                if f"quickpoll-{participant_id}" in function['FunctionName']:
                    lambda_functions.append(function['FunctionName'])
            
            if lambda_functions:
                lambda_regions[region] = lambda_functions
            
            # Check for API Gateway APIs
            apis = []
            response = apigw_client.get_rest_apis()
            
            for api in response.get('items', []):
                if f"quickpoll-api-{participant_id}" in api['name']:
                    apis.append(api['id'])
            
            if apis:
                api_gateway_regions[region] = apis
        
        except Exception as e:
            print(f"Error checking region {region}: {e}")
    
    # Determine if Lambda functions are deployed in multiple regions
    multi_region_lambda = len(lambda_regions) > 1
    multi_region_api = len(api_gateway_regions) > 1
    
    return {
        "implemented": multi_region_lambda and multi_region_api,
        "details": {
            "lambda_regions": lambda_regions,
            "api_gateway_regions": api_gateway_regions,
            "multi_region_lambda": multi_region_lambda,
            "multi_region_api": multi_region_api
        }
    }

async def check_route53_health_checks(participant_id, stack_name, credentials=None):
    """
    Check if the participant has configured Route 53 health checks.
    
    Args:
        participant_id: The unique identifier for the participant
        stack_name: The CloudFormation stack name
        credentials: Optional AWS credentials for cross-account access
        
    Returns:
        dict: Assessment result with implementation status and details
    """
    # Create boto3 session with optional credentials
    if credentials:
        session = boto3.Session(
            aws_access_key_id=credentials.get('aws_access_key_id'),
            aws_secret_access_key=credentials.get('aws_secret_access_key'),
            aws_session_token=credentials.get('aws_session_token')
        )
    else:
        session = boto3.Session()
    
    route53_client = session.client('route53')
    
    try:
        # Check for health checks
        health_checks = []
        response = route53_client.list_health_checks()
        
        for health_check in response.get('HealthChecks', []):
            # Check if this health check might belong to the participant
            # We can't directly check for participant_id in health checks
            # So we look for patterns in the configuration
            
            config = health_check.get('HealthCheckConfig', {})
            
            # If this is a CALCULATED health check, it could be for failover
            if config.get('Type') == 'CALCULATED':
                health_checks.append({
                    'Id': health_check['Id'],
                    'Type': 'CALCULATED',
                    'ChildHealthChecks': config.get('ChildHealthChecks', [])
                })
            
            # If it's an endpoint check, check if it might be for our API or website
            elif 'FullyQualifiedDomainName' in config:
                fqdn = config.get('FullyQualifiedDomainName', '')
                if 'execute-api' in fqdn or 'cloudfront' in fqdn:
                    health_checks.append({
                        'Id': health_check['Id'],
                        'Type': config.get('Type'),
                        'Endpoint': fqdn
                    })
        
        # Check for hosted zones with failover records
        hosted_zones = route53_client.list_hosted_zones()
        failover_records = []
        
        for zone in hosted_zones.get('HostedZones', []):
            zone_id = zone['Id']
            
            # Get record sets for this zone
            records = route53_client.list_resource_record_sets(HostedZoneId=zone_id)
            
            for record in records.get('ResourceRecordSets', []):
                # Check if this is a failover record
                if 'Failover' in record:
                    failover_records.append({
                        'Name': record['Name'],
                        'Type': record['Type'],
                        'Failover': record['Failover'],
                        'HealthCheckId': record.get('HealthCheckId', '')
                    })
        
        # Determine if Route 53 health checks are properly implemented
        has_health_checks = len(health_checks) > 0
        has_failover_records = len(failover_records) > 0
        
        return {
            "implemented": has_health_checks and has_failover_records,
            "details": {
                "health_checks": health_checks,
                "failover_records": failover_records,
                "has_health_checks": has_health_checks,
                "has_failover_records": has_failover_records
            }
        }
    
    except Exception as e:
        print(f"Error checking Route 53 health checks: {e}")
        return {
            "implemented": False,
            "details": {
                "error": str(e)
            }
        }

async def check_route53_failover_routing(participant_id, stack_name, credentials=None):
    """
    Check if the participant has configured Route 53 failover routing policies.
    
    Args:
        participant_id: The unique identifier for the participant
        stack_name: The CloudFormation stack name
        credentials: Optional AWS credentials for cross-account access
        
    Returns:
        dict: Assessment result with implementation status and details
    """
    # Create boto3 session with optional credentials
    if credentials:
        session = boto3.Session(
            aws_access_key_id=credentials.get('aws_access_key_id'),
            aws_secret_access_key=credentials.get('aws_secret_access_key'),
            aws_session_token=credentials.get('aws_session_token')
        )
    else:
        session = boto3.Session()
    
    route53_client = session.client('route53')
    
    try:
        # Check for hosted zones with failover records
        hosted_zones = route53_client.list_hosted_zones()
        primary_records = []
        secondary_records = []
        
        for zone in hosted_zones.get('HostedZones', []):
            zone_id = zone['Id']
            
            # Get record sets for this zone
            records = route53_client.list_resource_record_sets(HostedZoneId=zone_id)
            
            for record in records.get('ResourceRecordSets', []):
                # Check if this is a failover record
                if 'Failover' in record:
                    if record['Failover'] == 'PRIMARY':
                        primary_records.append({
                            'Name': record['Name'],
                            'Type': record['Type'],
                            'HealthCheckId': record.get('HealthCheckId', '')
                        })
                    elif record['Failover'] == 'SECONDARY':
                        secondary_records.append({
                            'Name': record['Name'],
                            'Type': record['Type'],
                            'HealthCheckId': record.get('HealthCheckId', '')
                        })
        
        # Determine if complete failover routing is implemented
        # We need both primary and secondary records for true failover routing
        has_primary = len(primary_records) > 0
        has_secondary = len(secondary_records) > 0
        has_complete_failover = has_primary and has_secondary
        
        # Check if we have records with health checks attached
        has_health_checks_attached = any(
            record.get('HealthCheckId') 
            for record in primary_records + secondary_records
        )
        
        return {
            "implemented": has_complete_failover and has_health_checks_attached,
            "details": {
                "primary_records": primary_records,
                "secondary_records": secondary_records,
                "has_primary": has_primary,
                "has_secondary": has_secondary,
                "has_health_checks_attached": has_health_checks_attached
            }
        }
    
    except Exception as e:
        print(f"Error checking Route 53 failover routing: {e}")
        return {
            "implemented": False,
            "details": {
                "error": str(e)
            }
        }

async def check_cross_region_monitoring(participant_id, stack_name, credentials=None):
    """
    Check if the participant has set up cross-region monitoring and alerting.
    
    Args:
        participant_id: The unique identifier for the participant
        stack_name: The CloudFormation stack name
        credentials: Optional AWS credentials for cross-account access
        
    Returns:
        dict: Assessment result with implementation status and details
    """
    # Create boto3 session with optional credentials
    if credentials:
        session = boto3.Session(
            aws_access_key_id=credentials.get('aws_access_key_id'),
            aws_secret_access_key=credentials.get('aws_secret_access_key'),
            aws_session_token=credentials.get('aws_session_token')
        )
    else:
        session = boto3.Session()
    
    # Regions to check
    regions = ['us-east-1', 'us-west-2', 'eu-west-1', 'ap-northeast-1']
    
    cloudwatch_alarms_by_region = {}
    dashboards = {}
    
    # Check each region for CloudWatch alarms
    for region in regions:
        cloudwatch_client = session.client('cloudwatch', region_name=region)
        
        try:
            # Check for CloudWatch alarms
            alarms = []
            response = cloudwatch_client.describe_alarms()
            
            for alarm in response.get('MetricAlarms', []):
                if participant_id in alarm['AlarmName']:
                    alarms.append({
                        'AlarmName': alarm['AlarmName'],
                        'Metric': alarm.get('MetricName', ''),
                        'Namespace': alarm.get('Namespace', '')
                    })
            
            if alarms:
                cloudwatch_alarms_by_region[region] = alarms
            
            # In primary region, check for dashboards that might include cross-region metrics
            if region == 'us-east-1':
                dashboard_response = cloudwatch_client.list_dashboards()
                
                for dashboard in dashboard_response.get('DashboardEntries', []):
                    if participant_id in dashboard['DashboardName']:
                        try:
                            dashboard_body = cloudwatch_client.get_dashboard(
                                DashboardName=dashboard['DashboardName']
                            )
                            
                            # Parse the dashboard JSON to see if it has multi-region widgets
                            dashboard_json = json.loads(dashboard_body['DashboardBody'])
                            has_cross_region = False
                            
                            for widget in dashboard_json.get('widgets', []):
                                properties = widget.get('properties', {})
                                metrics = properties.get('metrics', [])
                                
                                # Check if any metrics specify a region other than us-east-1
                                for metric in metrics:
                                    if isinstance(metric, list):
                                        for item in metric:
                                            if isinstance(item, dict) and 'region' in item:
                                                if item['region'] != 'us-east-1':
                                                    has_cross_region = True
                                                    break
                            
                            dashboards[dashboard['DashboardName']] = {
                                'has_cross_region_metrics': has_cross_region
                            }
                        
                        except Exception as e:
                            print(f"Error parsing dashboard: {e}")
        
        except Exception as e:
            print(f"Error checking CloudWatch in region {region}: {e}")
    
    # Check for SNS topics that might be used for cross-region alerting
    sns_client = session.client('sns', region_name='us-east-1')
    sns_topics = []
    
    try:
        topics_response = sns_client.list_topics()
        
        for topic in topics_response.get('Topics', []):
            arn = topic['TopicArn']
            if participant_id in arn:
                # Check subscriptions to see if there are email subscriptions
                subscriptions = sns_client.list_subscriptions_by_topic(TopicArn=arn)
                
                has_email_subscription = any(
                    sub['Protocol'] == 'email'
                    for sub in subscriptions.get('Subscriptions', [])
                )
                
                sns_topics.append({
                    'TopicArn': arn,
                    'has_email_subscription': has_email_subscription
                })
    
    except Exception as e:
        print(f"Error checking SNS topics: {e}")
    
    # Determine if cross-region monitoring is implemented
    has_multi_region_alarms = len(cloudwatch_alarms_by_region) > 1
    has_cross_region_dashboard = any(
        dashboard.get('has_cross_region_metrics', False)
        for dashboard in dashboards.values()
    )
    has_alerting = len(sns_topics) > 0 and any(
        topic.get('has_email_subscription', False)
        for topic in sns_topics
    )
    
    return {
        "implemented": has_multi_region_alarms and (has_cross_region_dashboard or has_alerting),
        "details": {
            "cloudwatch_alarms_by_region": cloudwatch_alarms_by_region,
            "dashboards": dashboards,
            "sns_topics": sns_topics,
            "has_multi_region_alarms": has_multi_region_alarms,
            "has_cross_region_dashboard": has_cross_region_dashboard,
            "has_alerting": has_alerting
        }
    }

async def check_cloudfront_origin_failover(participant_id, stack_name, credentials=None):
    """
    Check if the participant has configured CloudFront origin failover.
    
    Args:
        participant_id: The unique identifier for the participant
        stack_name: The CloudFormation stack name
        credentials: Optional AWS credentials for cross-account access
        
    Returns:
        dict: Assessment result with implementation status and details
    """
    # Create boto3 session with optional credentials
    if credentials:
        session = boto3.Session(
            aws_access_key_id=credentials.get('aws_access_key_id'),
            aws_secret_access_key=credentials.get('aws_secret_access_key'),
            aws_session_token=credentials.get('aws_session_token')
        )
    else:
        session = boto3.Session()
    
    cloudfront_client = session.client('cloudfront')
    
    try:
        # List CloudFront distributions
        distributions = cloudfront_client.list_distributions().get('DistributionList', {}).get('Items', [])
        
        cloudfront_with_failover = []
        origin_groups = {}
        
        for dist in distributions:
            # Check if this distribution belongs to the participant
            if participant_id in dist.get('Comment', ''):
                dist_id = dist['Id']
                
                # Get the distribution configuration in detail
                dist_config = cloudfront_client.get_distribution_config(Id=dist_id)
                
                config = dist_config.get('DistributionConfig', {})
                
                # Check for origin groups
                has_origin_groups = False
                if 'OriginGroups' in config:
                    origin_groups_config = config['OriginGroups']
                    if origin_groups_config.get('Quantity', 0) > 0:
                        has_origin_groups = True
                        
                        # Store details about the origin groups
                        groups = []
                        for group in origin_groups_config.get('Items', []):
                            failover_config = group.get('FailoverCriteria', {})
                            groups.append({
                                'Id': group.get('Id', ''),
                                'FailoverCriteria': failover_config.get('StatusCodes', {}).get('Items', [])
                            })
                        
                        origin_groups[dist_id] = groups
                
                if has_origin_groups:
                    cloudfront_with_failover.append(dist_id)
        
        # Determine if CloudFront origin failover is implemented
        has_origin_failover = len(cloudfront_with_failover) > 0
        
        return {
            "implemented": has_origin_failover,
            "details": {
                "cloudfront_with_failover": cloudfront_with_failover,
                "origin_groups": origin_groups
            }
        }
    
    except Exception as e:
        print(f"Error checking CloudFront origin failover: {e}")
        return {
            "implemented": False,
            "details": {
                "error": str(e)
            }
        }

async def check_end_to_end_failover(participant_id, stack_name, credentials=None):
    """
    Check if the participant has implemented end-to-end failover testing and validation.
    This is more complex to check automatically and requires examining multiple components.
    
    Args:
        participant_id: The unique identifier for the participant
        stack_name: The CloudFormation stack name
        credentials: Optional AWS credentials for cross-account access
        
    Returns:
        dict: Assessment result with implementation status and details
    """
    # This function will combine results from other checks to determine
    # if a complete end-to-end failover solution has been implemented
    
    # Create boto3 session with optional credentials
    if credentials:
        session = boto3.Session(
            aws_access_key_id=credentials.get('aws_access_key_id'),
            aws_secret_access_key=credentials.get('aws_secret_access_key'),
            aws_session_token=credentials.get('aws_session_token')
        )
    else:
        session = boto3.Session()
    
    # Check CloudWatch Logs for evidence of failover testing
    logs_client = session.client('logs')
    cloudformation_client = session.client('cloudformation')
    
    try:
        # Look for CloudWatch Log groups that might contain failover testing logs
        log_groups = []
        response = logs_client.describe_log_groups()
        
        for log_group in response.get('logGroups', []):
            if participant_id in log_group['logGroupName']:
                log_groups.append(log_group['logGroupName'])
        
        # Look for keywords in logs that might indicate failover testing
        failover_test_evidence = []
        
        for log_group_name in log_groups:
            # Get log streams
            streams_response = logs_client.describe_log_streams(
                logGroupName=log_group_name,
                orderBy='LastEventTime',
                descending=True,
                limit=5
            )
            
            for stream in streams_response.get('logStreams', []):
                # Get recent log events
                events_response = logs_client.get_log_events(
                    logGroupName=log_group_name,
                    logStreamName=stream['logStreamName'],
                    limit=100
                )
                
                # Look for keywords in logs
                for event in events_response.get('events', []):
                    message = event.get('message', '').lower()
                    if any(keyword in message for keyword in [
                        'failover', 'failback', 'disaster recovery', 'dr test',
                        'region failure', 'availability zone failure'
                    ]):
                        failover_test_evidence.append({
                            'logGroup': log_group_name,
                            'logStream': stream['logStreamName'],
                            'timestamp': event.get('timestamp'),
                            'message': event.get('message')
                        })
        
        # Check CloudFormation template outputs or metadata for DR documentation
        has_dr_documentation = False
        
        try:
            # Get stack details
            stack_response = cloudformation_client.describe_stacks(StackName=stack_name)
            
            for stack in stack_response.get('Stacks', []):
                # Check outputs for DR-related information
                for output in stack.get('Outputs', []):
                    output_key = output.get('OutputKey', '')
                    output_value = output.get('OutputValue', '')
                    output_description = output.get('Description', '').lower()
                    
                    if any(keyword in output_key.lower() for keyword in [
                        'failover', 'dr', 'disaster', 'recovery', 'multiregion'
                    ]) or any(keyword in output_description for keyword in [
                        'failover', 'disaster recovery', 'dr', 'multi-region'
                    ]):
                        has_dr_documentation = True
                
                # Check metadata for DR testing documentation
                try:
                    template_response = cloudformation_client.get_template(StackName=stack_name)
                    template_body = template_response.get('TemplateBody', {})
                    
                    # If template_body is a string (JSON/YAML), try to parse it
                    if isinstance(template_body, str):
                        try:
                            import yaml
                            template_body = yaml.safe_load(template_body)
                        except:
                            try:
                                template_body = json.loads(template_body)
                            except:
                                template_body = {}
                    
                    # Check Metadata section for DR documentation
                    metadata = template_body.get('Metadata', {})
                    for key, value in metadata.items():
                        if isinstance(value, dict) and any(
                            keyword in key.lower() for keyword in [
                                'failover', 'dr', 'disaster', 'recovery', 'testing'
                            ]
                        ):
                            has_dr_documentation = True
                
                except Exception as e:
                    print(f"Error checking template body: {e}")
        
        except Exception as e:
            print(f"Error checking stack details: {e}")
        
        # Determine if end-to-end failover is implemented
        # For this check, we consider evidence of testing, documentation, and other components
        
        # Get results from other checks (These would normally be passed in or stored in a database)
        # For demo purposes, we'll run them here, but in a real assessment, you'd have these results already
        multi_region_frontend = await check_multi_region_frontend_deployment(participant_id, stack_name, credentials)
        dynamodb_global_tables = await check_dynamodb_global_tables(participant_id, stack_name, credentials)
        multi_region_lambda = await check_multi_region_lambda_deployment(participant_id, stack_name, credentials)
        route53_health_checks = await check_route53_health_checks(participant_id, stack_name, credentials)
        route53_failover = await check_route53_failover_routing(participant_id, stack_name, credentials)
        cloudfront_origin_failover = await check_cloudfront_origin_failover(participant_id, stack_name, credentials)
        
        # Calculate an overall score for end-to-end failover
        components_implemented = [
            multi_region_frontend.get("implemented", False),
            dynamodb_global_tables.get("implemented", False),
            multi_region_lambda.get("implemented", False),
            route53_health_checks.get("implemented", False),
            route53_failover.get("implemented", False),
            cloudfront_origin_failover.get("implemented", False)
        ]
        
        # Count how many components are implemented
        component_count = sum(1 for comp in components_implemented if comp)
        
        # Evidence of testing increases the score
        has_failover_testing = len(failover_test_evidence) > 0
        
        # Full end-to-end failover requires most components plus evidence of testing or documentation
        end_to_end_implemented = (
            component_count >= 4 and (has_failover_testing or has_dr_documentation)
        )
        
        return {
            "implemented": end_to_end_implemented,
            "details": {
                "components_implemented": component_count,
                "total_components": len(components_implemented),
                "has_failover_testing": has_failover_testing,
                "has_dr_documentation": has_dr_documentation,
                "failover_test_evidence": failover_test_evidence
            }
        }
    
    except Exception as e:
        print(f"Error checking end-to-end failover: {e}")
        return {
            "implemented": False,
            "details": {
                "error": str(e)
            }
        }
```

## Step 7: Create the Assessment Engine Configuration

Now, let's create the configuration file for our challenge:

```python
# reliability_challenge_config.py

challenge_config = {
    "challenge_id": "single-point-failure",
    "name": "The Single-Point Failure",
    "description": "Improve a single-region application to be resilient against regional failures",
    "stack_name_prefix": "single-point-failure-",
    "assessment_criteria": [
        {
            "id": "multi-region-frontend",
            "name": "Multi-Region Frontend Deployment",
            "points": 10,
            "check_function": "check_multi_region_frontend_deployment",
            "description": "Deploy the website frontend (S3 buckets) in multiple regions",
            "suggestion": "Create S3 buckets in multiple regions and configure CloudFront with origin failover"
        },
        {
            "id": "dynamodb-global-tables",
            "name": "DynamoDB Global Tables Implementation",
            "points": 15,
            "check_function": "check_dynamodb_global_tables",
            "description": "Implement DynamoDB global tables for multi-region data replication",
            "suggestion": "Configure DynamoDB global tables to replicate data across regions and enable point-in-time recovery"
        },
        {
            "id": "multi-region-lambda",
            "name": "Lambda Functions Deployed Across Multiple Regions",
            "points": 15,
            "check_function": "check_multi_region_lambda_deployment",
            "description": "Deploy Lambda functions and API Gateway in multiple regions",
            "suggestion": "Create Lambda functions and API Gateway endpoints in secondary regions"
        },
        {
            "id": "route53-health-checks",
            "name": "Route 53 Health Checks Configuration",
            "points": 10,
            "check_function": "check_route53_health_checks",
            "description": "Configure Route 53 health checks to monitor regional endpoints",
            "suggestion": "Create health checks in Route 53 to monitor the availability of regional endpoints"
        },
        {
            "id": "route53-failover-routing",
            "name": "Route 53 Failover Routing Policies",
            "points": 15,
            "check_function": "check_route53_failover_routing",
            "description": "Implement Route 53 failover routing policies",
            "suggestion": "Set up failover routing policies in Route 53 to automatically redirect traffic during failures"
        },
        {
            "id": "cross-region-monitoring",
            "name": "Cross-Region Monitoring and Alerting",
            "points": 10,
            "check_function": "check_cross_region_monitoring",
            "description": "Implement cross-region monitoring and alerting",
            "suggestion": "Set up CloudWatch alarms, dashboards, and SNS notifications for multi-region monitoring"
        },
        {
            "id": "cloudfront-origin-failover",
            "name": "CloudFront Origin Failover Configuration",
            "points": 10,
            "check_function": "check_cloudfront_origin_failover",
            "description": "Configure CloudFront with origin failover",
            "suggestion": "Set up CloudFront origin groups with failover criteria"
        },
        {
            "id": "end-to-end-failover",
            "name": "End-to-End Failover Testing and Validation",
            "points": 15,
            "check_function": "check_end_to_end_failover",
            "description": "Implement and validate end-to-end failover",
            "suggestion": "Test and document end-to-end failover scenarios, including recovery procedures"
        }
    ],
    "passing_score": 80
}
```

## Step 8: Create Scoring Logic

Let's implement the scoring logic and feedback generator:

```python
# scoring_logic.py

def calculate_reliability_score(assessment_results):
    """Calculate a weighted reliability score based on assessment results"""
    # Define category weights
    weights = {
        "frontend": 0.15,  # Frontend components
        "backend": 0.25,   # Backend and data components
        "routing": 0.25,   # Traffic routing and DNS
        "testing": 0.15,   # Testing and validation
        "monitoring": 0.20 # Monitoring and alerting
    }
    
    # Map criteria to categories
    criteria_categories = {
        "multi-region-frontend": "frontend",
        "cloudfront-origin-failover": "frontend",
        "dynamodb-global-tables": "backend",
        "multi-region-lambda": "backend",
        "route53-health-checks": "routing",
        "route53-failover-routing": "routing",
        "cross-region-monitoring": "monitoring",
        "end-to-end-failover": "testing"
    }
    
    # Initialize category scores
    category_scores = {
        "frontend": {"earned": 0, "possible": 0},
        "backend": {"earned": 0, "possible": 0},
        "routing": {"earned": 0, "possible": 0},
        "testing": {"earned": 0, "possible": 0},
        "monitoring": {"earned": 0, "possible": 0}
    }
    
    # Calculate points for each category
    for result in assessment_results:
        criterion_id = result.get("criterionId")
        points = result.get("points", 0)
        max_points = result.get("maxPoints", 0)
        
        if criterion_id in criteria_categories:
            category = criteria_categories[criterion_id]
            category_scores[category]["earned"] += points
            category_scores[category]["possible"] += max_points
    
    # Calculate weighted score for each category
    weighted_scores = {}
    for category, weight in weights.items():
        earned = category_scores[category]["earned"]
        possible = category_scores[category]["possible"]
        
        # Avoid division by zero
        if possible > 0:
            score = (earned / possible) * 100
        else:
            score = 0
        
        weighted_scores[category] = score * weight
    
    # Calculate total weighted score
    total_score = sum(weighted_scores.values())
    
    return round(total_score)

def generate_feedback(assessment_results, reliability_score):
    """Generate educational feedback based on assessment results"""
    
    # Initialize feedback structure
    feedback = {
        "score": reliability_score,
        "passed": reliability_score >= 80,
        "summary": "",
        "implemented": [],
        "suggestions": []
    }
    
    # Generate summary message based on score
    if reliability_score >= 90:
        feedback["summary"] = "Excellent job! Your solution demonstrates a thorough understanding of multi-region resilience principles. The application is well-protected against regional failures."
    elif reliability_score >= 80:
        feedback["summary"] = "Good work! Your solution successfully implements key multi-region resilience patterns, providing protection against regional failures."
    elif reliability_score >= 60:
        feedback["summary"] = "You've made good progress, but the application still has some vulnerabilities to regional failures. Consider implementing the remaining resilience patterns."
    else:
        feedback["summary"] = "Your application needs more resilience improvements to protect against regional failures. Focus on implementing the suggested patterns to improve reliability."
    
    # Add detailed feedback for each assessment criterion
    for result in assessment_results:
        criterion_name = result.get("name", "")
        criterion_id = result.get("criterionId", "")
        implemented = result.get("implemented", False)
        points = result.get("points", 0)
        max_points = result.get("maxPoints", 0)
        details = result.get("details", {})
        
        # Get description and suggestion from challenge config
        description = next((
            criterion["description"] 
            for criterion in challenge_config["assessment_criteria"] 
            if criterion["id"] == criterion_id
        ), "")
        
        suggestion = next((
            criterion["suggestion"] 
            for criterion in challenge_config["assessment_criteria"] 
            if criterion["id"] == criterion_id
        ), "")
        
        # Add implemented or suggestions based on result
        if implemented:
            feedback["implemented"].append({
                "name": criterion_name,
                "description": description,
                "points": points,
                "details": details
            })
        else:
            feedback["suggestions"].append({
                "name": criterion_name,
                "description": description,
                "suggestion": suggestion,
                "points_available": max_points
            })
    
    # Add educational resources based on missing components
    if feedback["suggestions"]:
        feedback["learning_resources"] = [
            {
                "title": "AWS Multiple Region Multi-VPC Connectivity",
                "url": "https://aws.amazon.com/solutions/implementations/multi-region-application-architecture/"
            },
            {
                "title": "Building Multi-Region Applications with AWS Services",
                "url": "https://aws.amazon.com/blogs/architecture/building-multi-region-applications-with-aws-services/"
            },
            {
                "title": "Disaster Recovery of Workloads on AWS",
                "url": "https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-workloads-on-aws.html"
            }
        ]
    
    return feedback
```

## Step 9: Create an Assessment Runner

Now, let's create the main assessment runner script:

```python
#!/usr/bin/env python3
# assess_challenge.py

import boto3
import json
import asyncio
import importlib
import sys
from reliability_challenge_config import challenge_config
from scoring_logic import calculate_reliability_score, generate_feedback

async def assess_challenge(participant_id):
    """Run the assessment for a participant's solution"""
    print(f"Starting assessment for participant: {participant_id}")
    
    # Get stack name
    stack_name = f"{challenge_config['stack_name_prefix']}{participant_id}"
    
    # Import the check functions module
    try:
        check_functions = importlib.import_module("challenge_specific_checks")
    except ImportError as e:
        print(f"Error importing check functions: {e}")
        return None
    
    # Run assessment for each criterion
    results = []
    
    for criterion in challenge_config['assessment_criteria']:
        criterion_id = criterion['id']
        criterion_name = criterion['name']
        check_function_name = criterion['check_function']
        points = criterion['points']
        
        print(f"Checking criterion: {criterion_name} ({criterion_id})")
        
        # Check if the function exists
        if not hasattr(check_functions, check_function_name):
            print(f"  ❌ Function {check_function_name} not found")
            results.append({
                "criterionId": criterion_id,
                "name": criterion_name,
                "points": 0,
                "maxPoints": points,
                "implemented": False,
                "error": f"Check function not found: {check_function_name}"
            })
            continue
        
        try:
            # Get the check function
            check_function = getattr(check_functions, check_function_name)
            
            # Run the check function
            result = await check_function(participant_id, stack_name)
            
            # Check if result is in expected format
            if 'implemented' not in result:
                raise ValueError(f"Invalid result format: 'implemented' key is missing")
            
            # Add result to the list
            implemented = result.get('implemented', False)
            
            results.append({
                "criterionId": criterion_id,
                "name": criterion_name,
                "points": points if implemented else 0,
                "maxPoints": points,
                "implemented": implemented,
                "details": result.get('details', {})
            })
            
            # Print result
            if implemented:
                print(f"  ✅ Implementation detected")
            else:
                print(f"  ❌ Implementation not detected")
            
        except Exception as e:
            print(f"  ❌ Error executing {check_function_name}: {e}")
            
            results.append({
                "criterionId": criterion_id,
                "name": criterion_name,
                "points": 0,
                "maxPoints": points,
                "implemented": False,
                "error": str(e)
            })
    
    # Calculate score
    score = calculate_reliability_score(results)
    
    # Generate feedback
    feedback = generate_feedback(results, score)
    
    # Prepare assessment result
    assessment_result = {
        "participantId": participant_id,
        "challengeId": challenge_config['challenge_id'],
        "score": score,
        "results": results,
        "feedback": feedback,
        "passed": score >= challenge_config['passing_score']
    }
    
    return assessment_result

def save_assessment_result(assessment_result, output_file=None):
    """Save the assessment result to a file or database"""
    if not assessment_result:
        print("No assessment result to save")
        return
    
    # Format the result as JSON
    result_json = json.dumps(assessment_result, indent=2)
    
    # Determine output file name if not provided
    if not output_file:
        participant_id = assessment_result['participantId']
        output_file = f"assessment-result-{participant_id}.json"
    
    # Save to file
    with open(output_file, 'w') as f:
        f.write(result_json)
    
    print(f"Assessment result saved to {output_file}")
    
    # Print summary
    score = assessment_result['score']
    passed = assessment_result['passed']
    
    print("\nAssessment Summary:")
    print(f"Participant: {assessment_result['participantId']}")
    print(f"Challenge: {assessment_result['challengeId']}")
    print(f"Score: {score}/100")
    print(f"Result: {'PASSED' if passed else 'FAILED'}")
    
    # Print feedback
    feedback = assessment_result['feedback']
    print(f"\n{feedback['summary']}")
    
    # Print implemented criteria
    if feedback['implemented']:
        print("\nImplemented reliability patterns:")
        for item in feedback['implemented']:
            print(f"✅ {item['name']}")
    
    # Print suggestions
    if feedback['suggestions']:
        print("\nImprovement suggestions:")
        for item in feedback['suggestions']:
            print(f"❌ {item['name']}: {item['suggestion']}")

if __name__ == "__main__":
    # Get participant ID from command line
    if len(sys.argv) > 1:
        participant_id = sys.argv[1]
    else:
        print("Please provide a participant ID as a command-line argument")
        sys.exit(1)
    
    # Run the assessment
    result = asyncio.run(assess_challenge(participant_id))
    
    # Save the result
    if result:
        save_assessment_result(result)
    else:
        print("Assessment failed to complete")
        sys.exit(1)
```

## Step 10: Create Participant Instructions

Let's create detailed instructions for participants:

```markdown
# The Single-Point Failure Challenge

## Scenario

You've been hired as a reliability engineer for GlobalVote Inc., a company that provides voting services for online contests and elections. Their flagship application, "QuickPoll," has been gaining popularity, but last month they experienced a complete outage when AWS had service issues in their primary region.

The CEO has tasked you with making the application resilient against regional failures to prevent future outages. Currently, the entire application (web frontend, API layer, and database) is deployed in a single AWS region with no redundancy.

Your mission is to redesign and implement multi-region redundancy for the application while ensuring data consistency and minimal disruption during regional failures.

## Objective

Improve the QuickPoll application's reliability by implementing AWS Well-Architected Reliability Pillar best practices for multi-region resilience. You need to achieve a reliability score of at least 80 to pass this challenge.

## Current Architecture

The QuickPoll application currently has the following components:

1. **Frontend**: A static website hosted in an S3 bucket with a CloudFront distribution
2. **API Layer**: Lambda functions triggered by API Gateway
3. **Database**: DynamoDB table for storing polls and votes

The entire application is deployed in a single AWS region (us-east-1) with no redundancy, making it vulnerable to regional outages.

## Getting Started

1. Your deployment is available at:
   - **API Endpoint**: {api_endpoint}
   - **Website URL**: {website_url}
   - **CloudFront URL**: {cloudfront_url}

2. Examine the current architecture using the AWS Management Console
   - Review the CloudFormation stack to understand the current architecture
   - Identify single points of failure in the application

3. Implement multi-region resilience improvements
   - Add redundancy across multiple AWS regions
   - Configure automatic failover mechanisms
   - Ensure data consistency across regions

4. Submit your solution for assessment
   - When you're ready, run the assessment tool to check your progress:
     ```
     python assess_challenge.py {participant_id}
     ```

## Key Reliability Patterns to Consider

1. **Multi-Region Frontend Deployment**
   - Deploy static content to S3 buckets in multiple regions
   - Configure CloudFront with origin failover

2. **Global Data Replication**
   - Implement DynamoDB global tables
   - Enable point-in-time recovery for data protection

3. **Multi-Region API Layer**
   - Deploy Lambda functions in multiple regions
   - Set up API Gateway in multiple regions

4. **Intelligent Routing**
   - Configure Route 53 health checks
   - Implement failover routing policies

5. **Cross-Region Monitoring**
   - Set up CloudWatch dashboards with cross-region metrics
   - Configure alarms and notifications for regional issues

## Assessment Criteria

Your solution will be assessed based on the following criteria:

1. Multi-Region Frontend Deployment (10 points)
2. DynamoDB Global Tables Implementation (15 points)
3. Lambda Functions Deployed Across Multiple Regions (15 points)
4. Route 53 Health Checks Configuration (10 points)
5. Route 53 Failover Routing Policies (15 points)
6. Cross-Region Monitoring and Alerting (10 points)
7. CloudFront Origin Failover Configuration (10 points)
8. End-to-End Failover Testing and Validation (15 points)

To pass the challenge, you need to score at least 80 points.

## Learning Resources

- [Building Multi-Region Applications with AWS Services](https://aws.amazon.com/blogs/architecture/building-multi-region-applications-with-aws-services/)
- [DynamoDB Global Tables Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html)
- [Route 53 Failover Routing Documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-failover.html)
- [CloudFront Origin Failover Documentation](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/high_availability_origin_failover.html)
- [AWS Well-Architected Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)

Good luck improving the QuickPoll application's resilience!
```

## Step 11: Create Integration Script

Finally, let's create an integration script that brings everything together:

```python
#!/usr/bin/env python3
# setup_challenge.py

import boto3
import json
import subprocess
import sys
import os
import uuid
from deploy_challenge import deploy_for_participant

def setup_challenge():
    """Set up the challenge environment"""
    print("Setting up 'The Single-Point Failure' challenge environment...")
    
    # Check for AWS credentials
    try:
        sts = boto3.client('sts')
        identity = sts.get_caller_identity()
        print(f"Using AWS account: {identity['Account']}")
    except Exception as e:
        print(f"Error accessing AWS account: {e}")
        print("Please ensure AWS credentials are properly configured.")
        sys.exit(1)
    
    # Create output directory for challenge files
    os.makedirs("challenge-files", exist_ok=True)
    
    # Generate participant ID
    participant_id = f"participant-{uuid.uuid4().hex[:8]}"
    print(f"Generated participant ID: {participant_id}")
    
    # Deploy the challenge for the participant
    try:
        stack_name, outputs = deploy_for_participant(participant_id)
        print(f"Challenge deployed successfully. Stack: {stack_name}")
    except Exception as e:
        print(f"Error deploying challenge: {e}")
        sys.exit(1)
    
    # Generate participant instructions
    try:
        # Read template
        with open("participant_instructions_template.md", "r") as f:
            template = f.read()
        
        # Replace placeholders with actual values
        instructions = template.format(
            participant_id=participant_id,
            api_endpoint=outputs.get("ApiEndpoint", ""),
            website_url=outputs.get("WebsiteURL", ""),
            cloudfront_url=outputs.get("CloudFrontURL", "")
        )
        
        # Save instructions
        instructions_file = f"challenge-files/instructions-{participant_id}.md"
        with open(instructions_file, "w") as f:
            f.write(instructions)
        
        print(f"Participant instructions saved to {instructions_file}")
    except Exception as e:
        print(f"Error generating participant instructions: {e}")
    
    # Create challenge summary
    challenge_summary = {
        "challenge_id": "single-point-failure",
        "participant_id": participant_id,
        "stack_name": stack_name,
        "endpoints": outputs,
        "instructions_file": instructions_file
    }
    
    summary_file = f"challenge-files/challenge-summary-{participant_id}.json"
    with open(summary_file, "w") as f:
        json.dump(challenge_summary, f, indent=2)
    
    print(f"Challenge summary saved to {summary_file}")
    print("\nChallenge setup complete!")
    print(f"\nParticipant ID: {participant_id}")
    print(f"Instructions: {instructions_file}")
    print("\nTo assess the participant's solution, run:")
    print(f"python assess_challenge.py {participant_id}")

if __name__ == "__main__":
    setup_challenge()
```

## Step 12: Testing the Challenge

Here's a script to test your challenge implementation:

```python
#!/usr/bin/env python3
# test_challenge.py

import os
import json
import subprocess
import sys
import asyncio
from assess_challenge import assess_challenge

async def test_challenge():
    """Test the challenge implementation"""
    print("Testing 'The Single-Point Failure' challenge...")
    
    # Check if challenge summary exists
    summary_files = [f for f in os.listdir("challenge-files") if f.startswith("challenge-summary-")]
    
    if not summary_files:
        print("No challenge summary found. Please run setup_challenge.py first.")
        sys.exit(1)
    
    # Use the most recent summary file
    summary_file = os.path.join("challenge-files", sorted(summary_files)[-1])
    
    with open(summary_file, "r") as f:
        summary = json.load(f)
    
    participant_id = summary["participant_id"]
    stack_name = summary["stack_name"]
    
    print(f"Testing challenge for participant: {participant_id}")
    print(f"Stack name: {stack_name}")
    
    # Test the assessment engine
    print("\nTesting assessment engine...")
    assessment_result = await assess_challenge(participant_id)
    
    if assessment_result:
        print("Assessment engine test succeeded!")
        
        # Save the result
        test_result_file = f"challenge-files/test-assessment-{participant_id}.json"
        with open(test_result_file, "w") as f:
            json.dump(assessment_result, f, indent=2)
        
        print(f"Test assessment result saved to {test_result_file}")
        
        # Print summary
        score = assessment_result["score"]
        print(f"\nInitial score: {score}/100 (Expected to be low since no improvements have been made yet)")
        
        # Print missing implementations
        print("\nReliability patterns to implement:")
        for result in assessment_result["results"]:
            if not result["implemented"]:
                print(f"❌ {result['name']} ({result['maxPoints']} points)")
    else:
        print("Assessment engine test failed.")
        sys.exit(1)
    
    print("\nChallenge testing complete!")
    print("\nNext steps:")
    print("1. Implement the solution to make the application multi-region resilient")
    print("2. Run the assessment engine to check your progress:")
    print(f"   python assess_challenge.py {participant_id}")

if __name__ == "__main__":
    asyncio.run(test_challenge())
```

## Conclusion

You now have a complete implementation of "The Single-Point Failure" challenge for your AWS Reliability CTF event! This beginner-level challenge provides a great introduction to multi-region resilience concepts and follows the AWS Well-Architected Reliability Pillar best practices.

The implementation includes:

1. **Challenge Scenario and Learning Objectives**
   - A realistic scenario about a voting application needing multi-region resilience
   - Clear learning objectives focused on high availability patterns

2. **CloudFormation Templates**
   - Base template with a deliberately unreliable single-region application
   - Deployment script to create unique instances for each participant

3. **Assessment Engine**
   - Comprehensive check functions to evaluate each reliability pattern
   - Weighted scoring algorithm to calculate an overall reliability score
   - Detailed feedback generator with educational resources

4. **Participant Experience**
   - Clear instructions with background, objectives, and success criteria
   - Learning resources to help participants implement the reliability patterns

To run the challenge:

1. First, set up the challenge environment:
   ```
   python setup_challenge.py
   ```

2. Test the challenge assessment engine:
   ```
   python test_challenge.py
   ```

3. When a participant implements their solution, assess it:
   ```
   python assess_challenge.py <participant_id>
   ```

This challenge will provide participants with valuable hands-on experience in implementing AWS multi-region resilience patterns, which is a critical skill for building reliable cloud applications.