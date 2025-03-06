import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsgluedq.transforms import EvaluateDataQuality
from pyspark.sql.functions import (
    input_file_name, 
    regexp_replace,
    year,
    month,
    to_timestamp,
    col,
    date_format,
    when
)

# Then use a SQL transform to format the date
from awsglue.transforms import SelectFields
from awsglue.dynamicframe import DynamicFrame

args = getResolvedOptions(sys.argv, ['JOB_NAME','source_bucket','destination_bucket'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

source_bucket = args['source_bucket']
destination_bucket = args['destination_bucket']

source_path = f"s3://{source_bucket}/FOCUS Reports/"
destination_path = f"s3://{destination_bucket}/FOCUS/"

# Default ruleset used by all target nodes with data quality enabled
DEFAULT_DATA_QUALITY_RULESET = """
    Rules = [
        ColumnCount > 0
    ]
"""

# Script generated for node Amazon S3
# AmazonS3_node1737018309455 = glueContext.create_dynamic_frame.from_options(format_options={"quoteChar": "\"", "withHeader": True, "separator": ",", "optimizePerformance": False}, connection_type="s3", format="csv", connection_options={"paths": ["s3://sourceaws-513395669397/FOCUS Reports/"], "recurse": True, "compression": "zip"}, transformation_ctx="AmazonS3_node1737018309455")

AmazonS3_node1737018309455 = glueContext.create_dynamic_frame.from_options(format_options={"quoteChar": "\"", "withHeader": True, "separator": ",", "optimizePerformance": False}, connection_type="s3", format="csv", connection_options={"paths": [source_path], "recurse": True, "compression": "zip"}, transformation_ctx="AmazonS3_node1737018309455")

ChangeSchema_node1737018315517 = DynamicFrame.fromDF(
    AmazonS3_node1737018309455.toDF().selectExpr(
        "date_format(billingperiodstart, 'yyyy-MM') as billing_period",
		"availabilityzone",
		"CAST(billedcost AS FLOAT) as billedcost",
		"billingaccountid",
		"billingaccountname",
		"billingcurrency",
		"CAST(billingperiodend as timestamp) as billingperiodend",
		"CAST(billingperiodstart as timestamp) as billingperiodstart",
		"chargecategory",
		"chargedescription",
		"chargefrequency",
		"CAST(chargeperiodend as timestamp) as chargeperiodend",
		"CAST(chargeperiodstart as timestamp) as chargeperiodstart",
		"chargesubcategory",
		"commitmentdiscountcategory",
		"commitmentdiscountid",
		"commitmentdiscountname",
		"commitmentdiscounttype",
		"CAST(effectivecost AS FLOAT) as effectivecost",
		"invoiceissuer",
		"CAST(listcost AS FLOAT) as listcost",
		"CAST(listunitprice AS FLOAT) as listunitprice",
		"pricingcategory",
		"CAST(pricingquantity AS FLOAT) as pricingquantity",
		"pricingunit",
		"provider",
		"publisher",
		"region",
		"resourceid",
		"resourcename",
		"resourcetype",
		"servicecategory",
		"servicename",
		"skuid",
		"skupriceid",
		"subaccountid",
		"subaccountname",
		"tags",
		"CAST(usagequantity AS FLOAT) as usagequantity",
		"usageunit",
		"oci_referencenumber",
		"oci_compartmentid",
		"oci_compartmentname",
		"oci_overageflag",
		"oci_unitpriceoverage",
		"oci_billedquantityoverage",
		"oci_costoverage",
		"oci_attributedusage",
		"oci_attributedcost",
		"oci_backreferencenumber",
    ),
    glueContext,
    "formatted_data"
)

# Script generated for node Amazon S3
EvaluateDataQuality().process_rows(
	frame=ChangeSchema_node1737018315517, 
	ruleset=DEFAULT_DATA_QUALITY_RULESET, 
	publishing_options={
		"dataQualityEvaluationContext": "EvaluateDataQuality_node1737017837826",
		"enableDataQualityResultsPublishing": True
	}, 
	additional_options={
		"dataQualityResultsPublishing.strategy": "BEST_EFFORT", 
		"observations.scope": "ALL"
	}
)
AmazonS3_node1737018328443 = glueContext.write_dynamic_frame.from_options(
	frame=ChangeSchema_node1737018315517, connection_type="s3", 
	format="glueparquet", 
	connection_options={"path": destination_path, "partitionKeys": ["billing_period"]}, 
	format_options={"compression": "snappy"}, transformation_ctx="AmazonS3_node1737018328443"
)

job.commit()