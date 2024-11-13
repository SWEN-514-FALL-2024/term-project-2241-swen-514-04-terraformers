import json
import os
import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    # Initialize S3 client
    s3 = boto3.client('s3')
    
    try:
        # Get the folder name from the path parameter
        folder_name = event['pathParameters']['name']
        
        # Get the bucket name from environment variable
        bucket_name = os.environ['OUTPUT_BUCKET']
        
        # List objects in the specified folder
        response = s3.list_objects_v2(
            Bucket=bucket_name,
            Prefix=f"{folder_name}/",
            Delimiter='/'
        )
        
        # Check if folder exists
        if 'Contents' not in response:
            return {
                'statusCode': 404,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET,OPTIONS'
                },
                'body': json.dumps({
                    'message': f'Folder {folder_name} not found'
                })
            }
        
        # Initialize result dictionary
        result = {}
        
        # Process each file in the folder
        for obj in response['Contents']:
            # Skip the folder itself
            if obj['Key'].endswith('/'):
                continue
                
            # Only process .json files
            if not obj['Key'].endswith('.json'):
                continue
                
            # Get the file name without the folder prefix and extension
            file_name = obj['Key'].split('/')[-1].replace('.json', '')
            
            # Get the content of the file
            file_obj = s3.get_object(
                Bucket=bucket_name,
                Key=obj['Key']
            )
            
            # Read and parse the JSON content
            file_content = json.loads(file_obj['Body'].read().decode('utf-8'))
            
            # Add to result dictionary
            result[file_name] = file_content
        
        # Return successful response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            'body': json.dumps(result),
        }
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchBucket':
            return {
                'statusCode': 404,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET,OPTIONS'
                },
                'body': json.dumps({
                    'message': 'Specified bucket does not exist'
                })
            }
        else:
            return {
                'statusCode': 500,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET,OPTIONS'
                },
                'body': json.dumps({
                    'message': 'Internal server error'
                })
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            'body': json.dumps({
                'message': 'Internal server error'
            })
        }