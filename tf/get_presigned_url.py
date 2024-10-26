import json
import boto3
import os

def lambda_handler(event, context):

    try:
        # get bucket
        bucket = os.getenv('BUCKET_NAME')

        # get key
        body = event.get('body')
        body = json.loads(body)
        key = body["key"]

        # generate url
        s3 = boto3.client("s3")
        url = s3.generate_presigned_url('put_object', Params={"Bucket": bucket, "Key": key}, ExpiresIn=3600)
        
        return {
            "statusCode": "200",
            "body": {
                "url": url
            }

        }
    except:
        return {
            "statusCode": "500",
            "body": json.dumps("Internal Server Error")
        }