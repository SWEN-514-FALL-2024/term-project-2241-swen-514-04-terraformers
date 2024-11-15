import json
import boto3
import os
from datetime import datetime

def lambda_handler(event, context):
    # Parse the SNS message
    message = json.loads(event['Records'][0]['Sns']['Message'])
    
    # Get the job ID and status from the message
    job_id = message['JobId']
    status = message['Status']
    
    if status == 'SUCCEEDED':
        # Initialize clients
        rekognition_client = boto3.client('rekognition')
        s3_client = boto3.client('s3')
        
        # Get the full results from Rekognition
        labels = []
        next_token = None
        
        # Paginate through all results
        while True:
            if next_token:
                response = rekognition_client.get_label_detection(
                    JobId=job_id,
                    NextToken=next_token
                )
            else:
                response = rekognition_client.get_label_detection(JobId=job_id)
            
            labels.extend(response['Labels'])
            
            # Check if there are more results
            if 'NextToken' in response:
                next_token = response['NextToken']
            else:
                break
        
        # Process and structure the results
        processed_results = {
            'jobId': job_id,
            'videoMetadata': response['VideoMetadata'],
            'analysisTimestamp': datetime.now().isoformat(),
            'labels': []
        }
        
        # Group labels by timestamp
        timestamp_groups = {}
        for label in labels:
            timestamp = int(label['Timestamp'])
            if timestamp not in timestamp_groups:
                timestamp_groups[timestamp] = []
            
            # Extract relevant information from each label
            label_info = {
                'name': label['Label']['Name'],
                'confidence': label['Label']['Confidence'],
                'parents': [parent['Name'] for parent in label['Label'].get('Parents', [])]
            }
            timestamp_groups[timestamp].append(label_info)
        
        # Add organized labels to results
        for timestamp in sorted(timestamp_groups.keys()):
            processed_results['labels'].append({
                'timestamp': timestamp,
                'timestampSeconds': timestamp/1000.0,  # Convert to seconds
                'detectedLabels': timestamp_groups[timestamp]
            })
        
        video_name = message['Video']['S3ObjectName'].split('.')[0]  # Get video name from the original message
        
        # Save results to output bucket
        output_key = f"{video_name}/rekognition.json"
        s3_client.put_object(
            Bucket=os.environ['OUTPUT_BUCKET'],
            Key=output_key,
            Body=json.dumps(processed_results, indent=2),
            ContentType='application/json'
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'SUCCESS',
                'outputFile': output_key
            })
        }
    
    else:
        # Handle failed jobs
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'FAILED',
                'error': f"Rekognition job failed with status: {status}"
            })
        }