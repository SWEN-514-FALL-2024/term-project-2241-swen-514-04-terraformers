import json
import boto3
import os
import traceback

def lambda_handler(event, context):
    try:
        # get buckets
        input_bucket = os.environ['INPUT_BUCKET']
        output_bucket = os.environ['OUTPUT_BUCKET']

        # get key
        key:str = event.get('key')
        
        # Extract filename without extension to use as folder name
        filename = key.split(".")[0]

        # generate presigned url for input bucket
        s3 = boto3.client("s3")
        
        url = s3.generate_presigned_url(
            ClientMethod='put_object',
            Params={
                'Bucket': input_bucket,
                'Key': key,
                'ContentType': 'video/mp4'
            }
        )
        
        # Create empty folder in output bucket
        # S3 folders are created by adding a trailing slash to the key
        s3.put_object(
            Bucket=output_bucket,
            Key=f"{filename}/"
        )

        # Create name.json file in output bucket
        s3.put_object(
            Bucket=output_bucket,
            Key=f"{filename}/name.json",
            Body=json.dumps(event.get('name'))
        )
        
        return {
            "statusCode": "200",
            "body": {
                "url": url,
            }
        }
    except Exception as e:
        return {
            "statusCode": "500",
            "body": json.dumps(traceback.format_exc())
        }