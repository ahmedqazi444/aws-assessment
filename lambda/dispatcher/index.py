# lambda/dispatcher/index.py
import json
import os
import boto3

ecs = boto3.client('ecs')

def handler(event, context):
    region = os.environ.get('AWS_REGION', 'unknown')

    try:
        response = ecs.run_task(
            cluster=os.environ['ECS_CLUSTER_ARN'],
            taskDefinition=os.environ['ECS_TASK_DEFINITION'],
            count=1,
            launchType='FARGATE',
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': os.environ['SUBNETS'].split(','),
                    'securityGroups': [os.environ['SECURITY_GROUP']],
                    'assignPublicIp': 'ENABLED'
                }
            }
        )

        task_arn = response['tasks'][0]['taskArn'] if response.get('tasks') else 'No task started'

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'ECS task dispatched',
                'region': region,
                'task_arn': task_arn
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
