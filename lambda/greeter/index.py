# lambda/greeter/index.py
import json
import os
import uuid
import time
import boto3

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns', region_name='us-east-1')  # SNS topic is in us-east-1

def handler(event, context):
    region = os.environ.get('AWS_REGION', 'unknown')
    table_name = os.environ['DYNAMODB_TABLE']
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    email = os.environ['EMAIL']
    github_repo = os.environ['GITHUB_REPO']

    try:
        # Write to DynamoDB
        table = dynamodb.Table(table_name)
        table.put_item(Item={
            'id': str(uuid.uuid4()),
            'email': email,
            'region': region,
            'timestamp': str(int(time.time())),
            'source': 'Lambda'
        })

        # Publish to SNS
        sns.publish(
            TopicArn=sns_topic_arn,
            Message=json.dumps({
                'email': email,
                'source': 'Lambda',
                'region': region,
                'repo': github_repo
            }),
            Subject=f'Candidate Verification - Lambda - {region}'
        )

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Greeting logged',
                'region': region,
                'sns_published': True
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': str(e),
                'region': region
            })
        }
