import json
import boto3
import os

s3_client = boto3.client("s3")
rekognition_client = boto3.client("rekognition")

#Target bucket
target_bucket_name = os.getenv("TARGET_BUCKET_NAME")

def handler(event, context):
    # Retrieve the S3 bucket name and object key from the event
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    
    print(f"New file uploaded: {object_key} in bucket {bucket_name}")
    
    # Call Rekognition to detect labels in the image
    try:
        response = rekognition_client.detect_labels(
            Image={
                'S3Object': {
                    'Bucket': bucket_name,
                    'Name': object_key
                }
            },
            MaxLabels=10,
            MinConfidence=80
        )
        
        # Print out labels detected in the image
        labels = response['Labels']
        print("Detected labels in the image:")
        for label in labels:
            print(f"{label['Name']}: {label['Confidence']:.2f}% confidence")
        
        # save it back to a new file in the same bucket (as JSON):
        analysis_result = {
            "file": object_key,
            "labels": [
                {"name": label["Name"], "confidence": label["Confidence"]}
                for label in labels
            ]
        }
        
        # Save the result into target S3
        result_key = f"analysis_results/{object_key}.json"
        s3_client.put_object(
            Bucket=target_bucket_name,
            Key=result_key,
            Body=json.dumps(analysis_result)
        )
        
        print(f"Analysis results saved to {result_key} in bucket {target_bucket_name}")

    except Exception as e:
        print(f"Error processing image {object_key} in bucket {bucket_name}: {e}")

    return {
        "statusCode": 200,
        "body": json.dumps("Image analysis complete.")
    }
