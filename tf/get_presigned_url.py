import json
import boto3
import os

def lambda_handler(event, context):

    try:
        # get bucket
        bucket = os.environ['BUCKET_NAME']

        # get key
        key = event.get('key')

        # generate url
        s3 = boto3.client("s3")

        url = s3.generate_presigned_url(
            ClientMethod='put_object',
            Params={
                'Bucket': bucket,
                'Key': key,
                'ContentType': 'video/mp4'
            }
        )
        
        return {
            "statusCode": "200",
            "body": {
                "url": url
            }

        }
    except:
        return {
            "statusCode": "500",
            "body": json.dumps("Internal Server Error. Whoops.")
        }