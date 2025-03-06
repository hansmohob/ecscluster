import boto3
import os
import datetime
import json

#Write code for a function that accepts a string array of secret keys and return secret values in key pair format of secret
# key and secret value. The secret name is oci-secrets
def get_secrets(SecretId):
    secretresponses = {}
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=SecretId)
    secrets = response['SecretString']

    print(secrets)
    
    # Parse the JSON string from SecretString 
    secret_dict = json.loads(secrets)
    
    return secret_dict

def store_run_status(dynamodb_table_name, run_id, run_status):
        # Create a DynamoDB client
    dynamodb = boto3.client('dynamodb')
    
    # Create the DynamoDB table if it does not exist
    try:
        dynamodb.describe_table(TableName=dynamodb_table_name)
    except dynamodb.exceptions.ResourceNotFoundException:
        dynamodb.create_table(
            TableName=dynamodb_table_name,
            KeySchema=[
                {
                    'AttributeName': 'file_name',
                    'KeyType': 'HASH'
                }
            ],
            AttributeDefinitions=[
                {
                    'AttributeName': 'file_name',
                    'AttributeType': 'S'
                }
            ],
            ProvisionedThroughput={
                'ReadCapacityUnits': 5,
                'WriteCapacityUnits': 5
            }
        )
    # Create a DynamoDB client
    dynamodb = boto3.client('dynamodb')

    # Get the current timestamp
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Prepare the item to be stored in DynamoDB
    item = {
        'run_id': {'S': run_id},
        'run_status': {'S': run_status},
        'timestamp': {'S': timestamp}
    }

    # Store the item in DynamoDB
    dynamodb.put_item(TableName=dynamodb_table_name, Item=item)

def print_files_s3bucket(s3_client, bucket_name, Prefix):
    response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=Prefix)
    print("Files found in Bucket: "+bucket_name+" are: ")
    if 'Contents' in response:
        for obj in response['Contents']:
            #Print both the file name, path and the last modified date
            print(obj['Key'], obj['Size'], obj['LastModified'])
    else:
        print("No files found in the bucket "+bucket_name)    

def lambda_handler(event, context):
    
    cid_oci_secrets_name = os.environ['OracleSecretName']
    cid_oci_raw_s3 = os.environ['OciRawDataS3Bucket']
    cid_oci_s3_sync_start_date = os.environ['OCIToS3SyncStartDate']
    cid_oci_endpoint_url = os.environ['OracleEndpointURL']
    cid_oci_region = os.environ['OracleRegion']
    cid_oci_file_extension = os.environ['OCICopyFileExtension']
    cid_oci_sync_duration = os.environ['OCIToS3SyncDuration']

    #Get Secret from CID OCI Secrets Manager
    cid_oci_secrets = get_secrets(cid_oci_secrets_name)
    # print(cid_oci_secrets)
    cid_oci_access_key_id = cid_oci_secrets['oracle_access_key_id']
    cid_oci_secret_access_key = cid_oci_secrets['oracle_secret_access_secret']
    cid_oci_bucket = cid_oci_secrets['oracle_bucket']

    # Check if the secret is valid
    if cid_oci_access_key_id is None or cid_oci_secret_access_key is None:
        print("Invalid secret.")
        return
            
    # Get the AWS Raw bucket Details
    s3_aws = boto3.client('s3')
    print_files_s3bucket(s3_aws, cid_oci_raw_s3, "")

    s3_oci = boto3.client('s3',
                            endpoint_url=cid_oci_endpoint_url,
                            region_name=cid_oci_region,
                            aws_access_key_id=cid_oci_access_key_id,
                            aws_secret_access_key=cid_oci_secret_access_key)
    
    oci_result = s3_oci.list_objects(Bucket=cid_oci_bucket, Prefix='FOCUS Reports/')
    oci_files = oci_result.get("Contents")
    if oci_files is None:
        print("No files found in the OCI bucket.") #Need to put better contextual messages for multiple scenarios
        return
    else:
        print("Number of files found in the OCI bucket: ", len(oci_files))
        #print_files_s3bucket(s3_oci, cid_oci_bucket)
    
    # Get the timestamp to filter files. 'days' is the age filter and it only copies the files which are younger than the value specificied. 
    # It will only copy the files which have created/changed in the last x days
    timestamp = datetime.datetime.now() - datetime.timedelta(days=int(cid_oci_sync_duration))
    
    #File extension based filtering
    oci_filtered_files = [file for file in oci_files if file['Key'].endswith(cid_oci_file_extension) and 
                      datetime.datetime.strptime(file['LastModified'].strftime('%Y-%m-%d %H:%M:%S'), 
                      '%Y-%m-%d %H:%M:%S') > timestamp]

    print("Number of files found in the OCI bucket after filtering: ", len(oci_filtered_files))


    # Copy each file with the desired file extension to the OCI bucket
    for file in oci_filtered_files:
        obj = s3_oci.get_object(Bucket=cid_oci_bucket, Key=file['Key'])
        data = obj['Body'].read()
        # Replicate the AWS S3 bucket folder structure to the OCI bucket
        folder_structure = os.path.dirname(file['Key'])
        oci_key = folder_structure + '/' + os.path.basename(file['Key'])
        s3_aws.put_object(Bucket=cid_oci_raw_s3, Key=oci_key, Body=data) 