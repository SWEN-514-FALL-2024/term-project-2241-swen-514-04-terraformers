import json
import boto3
import os
import uuid

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    comprehend = boto3.client('comprehend')
    
    input_bucket = os.environ['INPUT_BUCKET']
    output_bucket = os.environ['OUTPUT_BUCKET']

    file = event['Records'][0]['s3']['object']['key']
    filename = file.split('.')[0]

    # job_name = f"{filename}_{str(uuid.uuid4())}"
    # job_uri = f"s3://{input_bucket}/{file}"

    # Take in transcribe output json data
    try:
        print("STARTING TO TAKE TRANSCRIBE JSON")
        transcribe_output_bucket = s3.get_object(Bucket=input_bucket, Key=file)
        transcribe_data = json.loads(transcribe_output_bucket['Body'].read().decode('utf-8'))

        print("TOOK TRANSCRIBE JSON, NOW TAKING THE TEXT")
        # Extract the transcribed text for analysis
        transcribed_text:str = transcribe_data.get('results', {}).get('transcripts', [{}])[0].get('transcript', "")
        transcribe_output_key = f"{filename}/transcribe.json"
        if transcribed_text is None or transcribed_text.strip() == '':
            # set transcribe and comprehend to false
            s3.put_object(
                Bucket=output_bucket,
                Key=transcribe_output_key,
                Body=json.dumps({"exists": False})
            )

            analysis_output_key = f"{filename}/comprehend.json"
            s3.put_object(
                Bucket=output_bucket,
                Key=analysis_output_key,
                Body=json.dumps({"exists": False})
            )

            return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Comprehend analysis success: No transcription, so no analysis was conducted.',
                'analysis_file': analysis_output_key
            })
        }
        else:
            s3.put_object(
                Bucket=output_bucket,
                Key=transcribe_output_key,
                Body=json.dumps({"exists": True, "data": transcribed_text})
            )

            print("Extracted transcribed text for Comprehend analysis.")
        
    except Exception as e:
        error = str(e)
        print(f"Error retrieving Transcribe output: {error}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Failed to retrieve Transcribe output',
                'error': error
            })
        }
    # Run Comprehend
    try:
        print("STARTING COMPREHEND")
        comprehend_response = comprehend.detect_sentiment(
            Text=transcribed_text,
            LanguageCode='en'
        )
        print("Comprehend analysis complete.")
        
        # Send result to S3
        analysis_output_key = f"{filename}/comprehend.json"
        s3.put_object(
            Bucket=output_bucket,
            Key=analysis_output_key,
            Body=json.dumps({"exists": True, "data": comprehend_response})
        )
        print(f"Analysis saved to {analysis_output_key} in Comprehend output bucket.")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Comprehend analysis success',
                'analysis_file': analysis_output_key
            })
        }
    
    except Exception as e:
        error = str(e)
        print(f"Error during Comprehend analysis: {error}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Failed to perform Comprehend analysis',
                'error': error
            })
        }