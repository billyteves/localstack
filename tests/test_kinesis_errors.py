import boto3
from nose.tools import assert_raises, assert_equal
from botocore.exceptions import ClientError
from localstack import config
from localstack.utils.common import *
from localstack.mock import infra
from localstack.utils.kinesis import kinesis_connector
from localstack.utils.aws import aws_stack
from .lambdas import lambda_integration

TEST_STREAM_NAME = lambda_integration.KINESIS_STREAM_NAME


def start_test(env=ENV_DEV):
    kinesis = aws_stack.connect_to_service('kinesis', env=env)
    stream = aws_stack.create_kinesis_stream(TEST_STREAM_NAME)

    records = [
        {
            'Data': '0',
            'ExplicitHashKey': '0',
            'PartitionKey': '0'
        }
    ]

    # by default, no errors
    test_no_errors = kinesis.put_records(StreamName='test-stream-1', Records=records)
    assert_equal(test_no_errors['FailedRecordCount'], 0)

    # with a probability of 1, always throw errors
    config.KINESIS_ERROR_PROBABILITY = 1.0
    test_all_errors = kinesis.put_records(StreamName='test-stream-1', Records=records)
    assert_equal(test_all_errors['FailedRecordCount'], 1)

    # reset probability to zero
    config.KINESIS_ERROR_PROBABILITY = 0.0
