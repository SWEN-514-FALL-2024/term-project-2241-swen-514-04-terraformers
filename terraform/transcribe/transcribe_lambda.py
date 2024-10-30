import json
import boto3
import os

def lambda_handler(event, context):
    transcribe = boto3.client('transcribe')
    
    bucket_name = os.environ['BUCKET_NAME']
    file_name = event['file_name']
    job_name = file_name.split('.')[0]
    job_uri = f"s3://{bucket_name}/{file_name}"

    # Start transcription job
    response = transcribe.start_transcription_job(
        TranscriptionJobName=job_name,
        Media={'MediaFileUri': job_uri},
        MediaFormat='mp4',
        LanguageCode='en-US'  # Adjust language code as needed
    )

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Transcription job started',
            'job_name': job_name
        })
    }
