import json
import boto3
import os

def remove_from_last(text: str, substring: str) -> str:
    last_index = text.rindex(substring)
    return text[:last_index]

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))
    
    # Extract job details from the EventBridge event
    detail = event['detail']
    job_name = detail['TranscriptionJobName']
    job_status = detail['TranscriptionJobStatus']
    
    transcribe = boto3.client('transcribe')
    
    s3 = boto3.client('s3')

    input_bucket = os.environ['INPUT_BUCKET']
    output_bucket = os.environ['OUTPUT_BUCKET']
    
    try:
        # Get filename from job name (remove UUID suffix)
        filename = remove_from_last(job_name, "_")
        output_key = f"{filename}/transcribe.json"
        
        if job_status == "COMPLETED":
            # Get the transcription job details
            transcribe_response = s3.get_object(
                Bucket=input_bucket,
                Key=f"{filename}.json"
            )
            
            transcribe_data = json.loads(transcribe_response['Body'].read().decode('utf-8'))
            transcribed_text:str = transcribe_data.get('results', {}).get('transcripts', [{}])[0].get('transcript', "")

            s3.put_object(
                Bucket=output_bucket,
                Key=output_key,
                Body=json.dumps({
                    "exists": True,
                    "data": transcribed_text,
                })
            )
            print(f"Transcription saved to {output_key} in Transcribe output bucket.")
        elif job_status == "FAILED":
            # Save failure status
            s3.put_object(
                Bucket=output_bucket,
                Key=output_key,
                Body=json.dumps({"exists": False})
            )

            s3.put_object(
                Bucket=output_bucket,
                Key=f"{filename}/comprehend.json",
                Body=json.dumps({"exists": False})
            )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully processed transcribe job {job_name}',
                'status': job_status
            })
        }
        
    except Exception as e:
        print(f"Error processing transcribe job: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error processing transcribe job',
                'error': str(e)
            })
        }