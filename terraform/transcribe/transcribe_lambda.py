import json
import boto3
import os

def lambda_handler(event, context):
    transcribe = boto3.client('transcribe')
    
    input_bucket = os.environ['INPUT_BUCKET']
    output_bucket = os.environ['OUTPUT_BUCKET']
    print(input_bucket, '\n')
    print(output_bucket,'\n')
    file_name = event['Records'][0]['s3']['object']['key']
    print(file_name)
    job_name = file_name.split('.')[0]
    job_uri = f"s3://{input_bucket}/{file_name}"

    # Start transcription job
    try:
        response = transcribe.start_transcription_job(
            TranscriptionJobName = job_name,
            Media = {'MediaFileUri': job_uri},
            MediaFormat = 'mp4',
            LanguageCode = 'en-US',
            OutputBucketName = output_bucket
        )
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Transcription job success',
                'job_name': job_name
            })
        }
    
    except Exception as e:
        error = str(e)
        print(f"Error starting transcription job: {error}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Failed to start transcription job',
                'error': error
            })
        }