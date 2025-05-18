# Assessment Engine - Architecture Overview

## 1. Introduction

The Dynamic Challenge Assessment Engine is a serverless system designed to evaluate AWS reliability implementations in a Capture The Flag (CTF) format. This architecture enables instructors and cloud engineers to create reliability-focused challenges that can be automatically assessed without requiring modifications to the core assessment engine. 

This document provides a comprehensive overview of the system's architecture, focusing on the Python implementation that enables dynamic code loading and secure cross-account assessment capabilities.

## 2. System Purpose and Design Philosophy

### 2.1. Core Objectives

The Assessment Engine addresses several key challenges in teaching AWS reliability principles:

1. **Decentralized Challenge Creation**: Allows multiple engineers to develop challenges independently without modifying the core assessment infrastructure, removing bottlenecks in challenge development.

2. **Automated Assessment**: Provides objective, consistent evaluation of participant solutions against predefined reliability criteria, reducing the manual effort required from instructors.

3. **Secure Isolation**: Maintains strict security boundaries between participant environments while still allowing automated assessment of their cloud resources.

4. **Educational Feedback**: Delivers specific, actionable feedback to help participants understand both what they implemented correctly and what could be improved.

### 2.2. Design Principles

The architecture follows several key design principles:

1. **Serverless-First**: Leverages AWS serverless technologies (Lambda, DynamoDB, S3) to minimize operational overhead and ensure elastic scaling during CTF events.

2. **Dynamic Code Loading**: Uses Python's module system to load and execute challenge-specific check functions at runtime, enabling challenge developers to define custom assessment logic.

3. **Secure Cross-Account Access**: Implements a carefully designed cross-account role structure that provides the minimum necessary permissions for assessment.

4. **Standardized Interface**: Defines a clear contract for challenge definitions and check functions, making it easy for challenge developers to create new content.

## 3. Core Architecture Components

The system follows a hub-and-spoke model with a central Challenge Management Account that contains the assessment engine and challenge repository, connected to multiple Team Accounts where participants deploy their solutions.

### 3.1. Challenge Management Account

This account serves as the central hub and contains the following components:

#### 3.1.1. Storage Layer

**S3 Challenge Repository**:
- Stores challenge definitions, check functions, and related resources
- Organized with a standardized directory structure
- Each challenge has its own directory containing:
  - `config.json`: Challenge metadata and assessment criteria
  - `check-functions.py`: Python code that evaluates specific reliability aspects
  - `resources/`: Additional files needed for the challenge

**DynamoDB Tables**:
- **Challenge Registry Table**: Stores metadata about available challenges
  - Primary key: `challengeId`
  - Contains information like name, description, S3 location, and active status
- **Assessment Results Table**: Records participant assessment outcomes
  - Primary key: Composite of `participantId` and `challengeId`
  - Stores details of which criteria were met, scores, and timestamps

#### 3.1.2. Compute Layer

**Assessment Engine Lambda Function**:
- Core Python function that orchestrates the assessment process
- Dynamically loads check functions from S3 at runtime
- Assumes IAM roles in team accounts to evaluate participant resources
- Calculates scores based on implemented reliability features
- Writes results to DynamoDB and returns feedback to the participant

**Challenge Management Lambda Functions**:
- Handle CRUD operations for challenges
- Validate challenge structure and contents
- Register challenges in the registry

#### 3.1.3. API Layer

**Challenge Management API**:
- RESTful endpoints for administrators to manage challenges
- Backed by API Gateway and Lambda functions
- Secured with appropriate authentication mechanisms

**Assessment API**:
- Endpoint for participants to request assessment of their solutions
- Triggers the Assessment Engine Lambda function
- Returns assessment results and feedback

### 3.2. Team Accounts

Each team has a dedicated AWS account containing:

**Cross-Account IAM Role**:
- Named `AssessmentEngineAccessRole`
- Allows the Assessment Engine Lambda function to assume this role
- Contains permissions to evaluate resources in the team account
- Enhanced security with external ID and strict trust policy

**Participant Resources**:
- CloudFormation stacks created by participants
- Resources that implement reliability patterns being assessed
- Isolated per participant to prevent interference

## 4. Technical Implementation Details

### 4.1. Dynamic Code Loading Mechanism

The most technically innovative aspect of the system is how it securely loads and executes challenge-specific check functions at runtime. This is implemented using Python's `importlib` module:

1. The Assessment Engine Lambda retrieves the challenge definition from DynamoDB
2. It downloads the check functions file from S3
3. It creates a temporary file from the S3 content
4. It dynamically loads the file as a Python module using `importlib.util`
5. It executes specific check functions from the module based on the challenge criteria

This approach provides several benefits:
- Challenge-specific code is completely decoupled from the assessment engine
- New challenges can be added without modifying or redeploying the engine
- Check functions are isolated in their own module namespace
- The engine can enforce timeouts and handle errors from check functions

### 4.2. Cross-Account Assessment Flow

The assessment process works across account boundaries through the following steps:

1. Participant requests an assessment through the Assessment API
2. Assessment Engine Lambda function is triggered with the participant ID and challenge ID
3. Lambda loads the challenge configuration and check functions
4. Lambda assumes the `AssessmentEngineAccessRole` in the team account using STS with an external ID
5. Lambda passes the temporary credentials to the check functions
6. Check functions use these credentials to evaluate resources in the team account
7. Assessment results are calculated, stored, and returned to the participant

This cross-account model provides strong security segregation while still enabling automated assessment.

### 4.3. Challenge Structure and Interface

#### Challenge Configuration (config.json)

```json
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
    }
  ],
  "stackNamePrefix": "reliability-challenge-",
  "passingScore": 80
}
```

#### Check Functions Interface

Each check function must implement this interface:

```python
def check_function_name(participant_id, stack_name, credentials=None):
    """
    Evaluates a specific reliability aspect of a participant's implementation.
    
    Args:
        participant_id (str): Unique identifier for the participant
        stack_name (str): Name of the CloudFormation stack to evaluate
        credentials (dict): AWS credentials for accessing the team account
        
    Returns:
        dict: Result containing at minimum:
            - implemented (bool): Whether the criterion is successfully implemented
            - details (dict): Additional information about the implementation
    """
    # Implementation-specific code
    return {
        "implemented": True,
        "details": {
            # Criterion-specific details
        }
    }
```

## 5. Security Considerations

### 5.1. Dynamic Code Execution

Since the system dynamically loads and executes code from S3, several security measures are implemented:

1. **Input Validation**: Checks that loaded code follows expected interfaces
2. **Error Containment**: Prevents errors in check functions from affecting the assessment engine
3. **Function Timeouts**: Limits execution time to prevent infinite loops or resource exhaustion
4. **Clean Temporary Files**: Ensures temporary files created during code loading are properly deleted

### 5.2. Cross-Account Access

Cross-account access is tightly controlled through:

1. **Least Privilege**: The assessment role has only the permissions needed to evaluate resources
2. **External ID**: Uses STS External ID to prevent confused deputy problems
3. **Short-lived Credentials**: Temporary credentials have limited validity periods
4. **Scoped Session Policies**: Further restricts what the assumed role can do
5. **Audit Logging**: Comprehensive logging of all cross-account operations

### 5.3. API Security

The APIs are protected by:

1. **Authentication**: Users must authenticate before accessing the APIs
2. **Input Validation**: All API inputs are validated to prevent injection attacks
3. **Rate Limiting**: Prevents abuse of the assessment endpoint
4. **HTTPS**: All communication is encrypted in transit

## 6. Monitoring and Operations

### 6.1. Logging Strategy

The system implements a comprehensive logging strategy:

1. **Structured Logging**: All logs use a consistent JSON format
2. **Log Levels**: Appropriate log levels to control verbosity
3. **Context Preservation**: Each log entry includes participant ID, challenge ID, and request ID
4. **Error Tracking**: Detailed error logs with stack traces for troubleshooting

### 6.2. Metrics and Alerts

Key metrics are tracked through CloudWatch:

1. **Assessment Completions**: Tracks successful and failed assessments
2. **Assessment Duration**: Monitors performance of check functions
3. **Error Rates**: Alerts on unusual error patterns
4. **Resource Utilization**: Monitors Lambda concurrency and DynamoDB capacity

## 7. Extensibility and Future Enhancements

The architecture is designed to be extensible in several ways:

1. **New Challenge Types**: Support for different types of reliability challenges
2. **Enhanced Feedback**: More detailed feedback with visual representations
3. **Real-time Events**: WebSocket integration for real-time assessment updates
4. **Multi-region Deployment**: Extending the system to operate across multiple AWS regions
5. **Machine Learning**: Potential for ML-based scoring of certain implementation aspects

## 8. Conclusion

The Dynamic Challenge Assessment Engine provides a scalable, secure, and flexible platform for creating and assessing AWS reliability challenges. By decoupling challenge definition from the assessment infrastructure, it enables a collaborative approach to challenge development while maintaining security and consistency.

The Python implementation offers an ideal balance of security, flexibility, and ease of development, making it particularly well-suited for educational environments where challenge content needs to evolve rapidly.
