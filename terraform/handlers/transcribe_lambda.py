import json
import boto3
import os
import uuid

def lambda_handler(event, context):
    transcribe = boto3.client('transcribe')
    rekognition_client = boto3.client("rekognition")
    
    input_bucket = os.environ['INPUT_BUCKET']
    output_bucket = os.environ['OUTPUT_BUCKET']

    file = event['Records'][0]['s3']['object']['key']
    filename = file.split('.')[0]

    job_name = f"{filename}_{str(uuid.uuid4())}"
    job_uri = f"s3://{input_bucket}/{file}"

    # Start transcription job
    try:
        transcribe_response = transcribe.start_transcription_job(
            TranscriptionJobName = job_name,
            Media = {'MediaFileUri': job_uri},
            MediaFormat = 'mp4',
            LanguageCode = 'en-US',
            OutputBucketName = output_bucket,
            OutputKey = f"{filename}.json"
        )

        # Start Rekognition Video Analysis
        rekognition_response = rekognition_client.start_label_detection(
            Video={
                'S3Object': {
                    'Bucket': input_bucket,
                    'Name': file
                }
            },
            NotificationChannel={
                'SNSTopicArn': os.environ['SNS_TOPIC_ARN'],
                'RoleArn': os.environ['REKOGNITION_ROLE_ARN']
            },
            JobTag=job_name
        )

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Transcribe + Rekognition job success',
                'job_name': filename
            })
        }
    
    except Exception as e:
        error = str(e)
        print(f"Error starting Transcribe + Rekognition job: {error}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Failed to start Transcribe + Rekognition job',
                'error': error
            })
        }