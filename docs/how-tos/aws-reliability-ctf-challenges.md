# AWS Well-Architected Reliability Pillar CTF Challenges

This document presents a collection of 10 potential challenges for an AWS Well-Architected Reliability Pillar Capture The Flag (CTF) event. These challenges span multiple difficulty levels and cover various aspects of reliability engineering in AWS environments.

| Difficulty Level | Challenge Name | Resiliency Challenge Type | Challenge Description | Description of Resilience Issue/Defect | Skills Tested | Potential Observability Tools |
|------------------|----------------|---------------------------|------------------------|---------------------------------------|---------------|------------------------------|
| Beginner | The Single-Point Failure | High Availability | Improve a single-region application to be resilient against regional failures | Application deployed in a single AWS region with no redundancy, causing total outage during regional issues | Multi-region architecture, read replicas, global tables, cross-region replication | AWS CloudWatch, AWS Health Dashboard, Route 53 Health Checks, Global Accelerator metrics |
| Beginner | Database Durability Gap | Backup & Recovery | Implement proper backup strategies for a critical database | DynamoDB table without point-in-time recovery enabled, vulnerable to data loss | Database backup configuration, recovery testing, retention policies | CloudWatch metrics for backup events, AWS Backup dashboard, CloudTrail for configuration changes |
| Intermediate | The Error Cascade | Error Handling | Fix a serverless application with poor error handling that crashes during peak loads | Lambda functions missing error handling, DLQs, and retry mechanisms causing cascading failures | Lambda error handling, SQS DLQ implementation, retry strategies with backoff | CloudWatch Logs, X-Ray for tracing error paths, Lambda Insights, SQS queue metrics |
| Intermediate | The Silent Degradation | Performance Monitoring | Identify and fix subtle performance degradation that doesn't trigger alerts but impacts users | Services experiencing gradual latency without triggering threshold-based alerts | Service latency analysis, distributed tracing, anomaly detection | AWS X-Ray, CloudWatch ServiceLens, CloudWatch Synthetics, CloudWatch Anomaly Detection |
| Intermediate | The Quota Crunch | Service Quotas Management | Diagnose and resolve an application hitting AWS service quotas during peak usage | Application built without considering service quotas and limits | Service quotas monitoring, architectural changes to work within limits | Service Quotas dashboard, CloudWatch metrics, Trusted Advisor, X-Ray for bottleneck analysis |
| Advanced | Overload Preventer | Load Management & Throttling | Implement throttling and load shedding for an API experiencing request floods | API Gateway and backend services crashing under heavy load with no protection | API throttling, load shedding, client-side retry, queue-based architecture | API Gateway dashboard, CloudWatch metrics, X-Ray tracing, SQS queue metrics |
| Advanced | The Circuit Breaker | Fault Isolation | Implement a circuit breaker pattern for an application dependent on unreliable third-party services | Microservices failing due to dependency on unstable external services with no isolation | Circuit breaker pattern, fallback mechanisms, dependency isolation | X-Ray tracing for dependencies, CloudWatch synthetic canaries, custom circuit state metrics |
| Advanced | Recovery Orchestrator | Disaster Recovery | Design and implement an automated disaster recovery solution with defined RPO/RTO | Manual recovery processes with undefined recovery objectives leading to extended outages | DR automation, cross-region replication, recovery testing | CloudWatch Events/EventBridge, AWS Backup metrics, Route 53 failover metrics, recovery time measurement |
| Advanced | The Chaos Engineer | Resilience Testing | Improve system resilience after identifying weaknesses through controlled chaos experiments | System fails under specific failure scenarios that weren't anticipated | Chaos engineering principles, failure injection, resilience improvements | AWS Fault Injection Simulator, CloudWatch dashboards, X-Ray insights, custom resilience metrics |
| Expert | Global Resilience Architect | Global Multi-Region Architecture | Design and implement a global multi-region active-active architecture with data consistency | Complex application with data synchronization challenges across multiple global regions | Multi-region active-active architecture, conflict resolution, global routing strategies | Global service metrics, Route 53 traffic flow analysis, CloudFront logs, DynamoDB Global Tables metrics |

## Challenge Implementation Recommendations

For effective implementation of these CTF challenges, each challenge should include the following components:

### 1. Architecture Documentation

- **Unreliable Architecture**: Provide detailed documentation and diagrams showing the deliberately unreliable starting architecture, highlighting known issues and reliability weaknesses. This gives participants a clear understanding of what they need to improve.

- **Target Architecture**: Create reference documentation showing the ideal reliable architecture that resolves all reliability issues. This serves as a guide for the assessment engine and helps in scoring participants' solutions.

### 2. CloudFormation Templates

- **Base Template**: Develop an unreliable base template that participants will need to improve. This template should deploy a functional but reliability-challenged application.

- **Reference Solution Template**: Create a template implementing all expected reliability improvements. This serves as a benchmark for the assessment engine but is not shared with participants.

- **Deployment Script**: Create scripts to deploy unique instances for each participant, using parameters to differentiate between participant environments.

### 3. Assessment Engine

- **Dynamic Loading**: Implement assessment engine using the "Dynamic Challenge Assessment Engine" approach, allowing challenge-specific check functions to be stored in S3 and loaded at runtime.

- **Check Functions**: Develop specific check functions for each reliability improvement participants are expected to implement. These functions should evaluate whether participants' solutions correctly implement reliability patterns.

- **Cross-Account Access**: Set up secure IAM roles to allow the assessment engine to evaluate resources in participants' accounts without compromising security.

### 4. Scoring Methodology

- **Category Weights**: Define scoring categories and weights based on the importance of different reliability aspects (e.g., High Availability: 35%, Error Handling: 25%, etc.).

- **Scoring Logic**: Implement scoring algorithms that calculate points based on which reliability improvements have been implemented correctly.

- **Feedback Generator**: Create a mechanism to provide educational feedback based on assessment results, helping participants learn even if they don't fully solve the challenge.

### 5. Participant Experience

- **Challenge Instructions**: Develop detailed instructions including scenario description, objectives, and getting started guides. These should provide enough context without giving away solutions.

- **Learning Resources**: Include links to AWS documentation, blog posts, and other resources to help participants learn about relevant reliability principles.

- **Progress Tracking**: Create a dashboard for participants to track their progress and see which reliability improvements they've successfully implemented.

### 6. Testing Framework

- **Validation Testing**: Implement tests to verify that the assessment engine correctly evaluates different levels of reliability implementations.

- **Load Testing**: For challenges focused on handling load, include mechanisms to generate realistic load patterns.

- **Chaos Testing**: For advanced challenges, include controlled chaos experiments to verify resilience improvements.

By following these recommendations, you can create engaging, educational CTF challenges that effectively teach AWS Well-Architected Reliability principles through hands-on problem-solving.
