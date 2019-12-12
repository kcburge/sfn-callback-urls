##########################################https://learn.hashicorp.com/terraform/aws/lambda-api-gateway
# https://www.terraform.io/docs/providers/aws/r/api_gateway_integration.html

# Copyright 2019 Ben Kehoe
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Transform: 'AWS::Serverless-2016-10-31'
# Metadata:
#   AWS::ServerlessRepo::Application:
#     Name: sfn-callback-urls
#     Description: Easy handling of Step Function tokens as callback URLs
#     Author: Ben Kehoe
#     Labels:
#       - stepfunctions
#       - callback
#       - email
#     SpdxLicenseId: Apache-2.0
#     LicenseUrl: LICENSE
#     ReadmeUrl: README.md
#     HomePageUrl: https://github.com/benkehoe/sfn-callback-urls
#     SemanticVersion: 1.0.0
#     SourceCodeUrl: https://github.com/benkehoe/sfn-callback-urls
# Parameters:
#   DisableEncryption:
#     Description: Disable encryption for callback payloads
#     Type: String
#     AllowedValues:
#       - "true"
#       - "false"
#     Default: "false"
#   EncryptionKeyArn:
#     Description: If encryption is enabled, set this to use your own KMS key, or set to NONE to create one
#     Type: String
#     Default: 'NONE'
#   EnableOutputParameters:
#     Description: Allow the use of query parameters to customize the result of callbacks
#     Type: String
#     AllowedValues:
#       - "true"
#       - "false"
#     Default: "false"
#   EnablePostActions:
#     Description: Allow the use of post actions, which pass the callback request body to Step Functions
#     Type: String
#     AllowedValues:
#       - "true"
#       - "false"
#     Default: "false"
#   VerboseLogging:
#     Description: Log requests and payloads
#     Type: String
#     AllowedValues:
#       - "true"
#       - "false"
#     Default: "false"
# Conditions:
#   EncryptionEnabled:
#     Fn::Equals: [ !Ref DisableEncryption, "false" ]
#   CreateKey:
#     Fn::And:
#       - Fn::Equals: [ !Ref DisableEncryption, "false" ]
#       - Fn::Equals: [ !Ref EncryptionKeyArn, "NONE" ]
#   OutputParametersDisabled:
#     Fn::Equals: [ !Ref EnableOutputParameters, "false" ]
#   PostActionsDisabled:
#     Fn::Equals: [ !Ref EnablePostActions, "false" ]
#   VerboseLoggingEnabled:
#     Fn::Equals: [ !Ref VerboseLogging, "true" ]

resource "aws_iam_policy" "create_urls" {
  description = "Permission to call the API and the function directly"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "execute-api:Invoke",
      "Resource": "!Sub arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${Api}/${ApiStage}/*"
    },
    {
      "Effect": "Allow",
      "Action": "lambda:Invoke",
      "Resource": "!GetAtt CreateUrls.Arn"
    }
  ]
}
EOF
}

resource "aws_api_gateway_rest_api" "this" {
  name = "Callback URLs service for Step Functions"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "create_urls" {
  rest_api_id = "${aws_api_gateway_rest_api.this.id}"
  parent_id   = "${aws_api_gateway_rest_api.this.root_resource_id}"
  path_part   = "urls"
}

resource "aws_api_gateway_method" "create_urls" {
  rest_api_id   = "${aws_api_gateway_rest_api.this.id}"
  resource_id   = "${aws_api_gateway_resource.create_urls.id}"
  http_method   = "POST"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "create_urls" {
  rest_api_id             = "${aws_api_gateway_rest_api.this.id}"
  resource_id             = "${aws_api_gateway_resource.create_urls.resource_id}"
  http_method             = "${aws_api_gateway_method.create_urls.http_method}"
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "${aws_lambda_function.create_urls_for_api.invoke_arn}"
}

resource "aws_lambda_permission" "create_urls" {
  function_name = "${aws_lambda_function.create_urls_for_api.id}"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

# process callback

resource "aws_api_gateway_resource" "process_callback" {
  rest_api_id = "${aws_api_gateway_rest_api.this.id}"
  parent_id   = "${aws_api_gateway_rest_api.this.root_resource_id}"
  path_part   = "respond"
}

resource "aws_api_gateway_method" "process_callback_get" {
  rest_api_id   = "${aws_api_gateway_rest_api.this.id}"
  resource_id   = "${aws_api_gateway_resource.process_callback.id}"
  http_method   = "GET"
  authorization = "NONE"

  #       Integration:
  #         Type: AWS_PROXY
  #         IntegrationHttpMethod: POST
  #         Uri: !Sub "arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS::Region}:${AWS::AccountId}:function:${ProcessCallbackFunction}/invocations"
}

resource "aws_api_gateway_method" "process_callback_post" {
  rest_api_id   = "${aws_api_gateway_rest_api.this.id}"
  resource_id   = "${aws_api_gateway_resource.process_callback.id}"
  http_method   = "POST"
  authorization = "NONE"

  #       Integration:
  #         Type: AWS_PROXY
  #         IntegrationHttpMethod: POST
  #         Uri: !Sub "arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS::Region}:${AWS::AccountId}:function:${ProcessCallbackFunction}/invocations"
}

resource "aws_lambda_permission" "process_callback" {
  function_name = "${aws_lambda_function.process_callback.id}"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_iam_role" "create_urls" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "create_urls_logs" {
  policy_name = "LambdaLogging"

  #       Roles:
  #       - !Ref CreateUrlsRole
  #       PolicyName: LambdaLogging
  #       PolicyDocument:
  #         Version: "2012-10-17"
  #         Statement:
  #           - Effect: Allow
  #             Action:
  #               - "logs:CreateLogStream"
  #               - "logs:CreateLogGroup"
  #             Resource:
  #               - !Sub "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${CreateUrls}:*"
  #               - !Sub "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${CreateUrlsForApi}:*"
  #           - Effect: Allow
  #             Action:
  #               - "logs:PutLogEvents"
  #             Resource:
  #               - !Sub "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${CreateUrls}:log-stream:*"
  #               - !Sub "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${CreateUrlsForApi}:log-stream:*"
}

resource "aws_lambda_function" "create_urls_for_api" {
  function_name = "create-urls-for-api"

  #       CodeUri: ./src
  #       Runtime: python3.6
  #       Handler: create_urls.api_handler
  #       Role: !GetAtt CreateUrlsRole.Arn
  #       MemorySize: 1024
  #       Environment:
  #         Variables:
  #           DISABLE_OUTPUT_PARAMETERS: {"Fn::If": [OutputParametersDisabled, "true", "false"]}
  #           DISABLE_POST_ACTIONS: {"Fn::If": [PostActionsDisabled, "true", "false"]}
  #           VERBOSE: {"Fn::If": [VerboseLoggingEnabled, "true", "false"]}
  #           KEY_ID:
  #             "Fn::If":
  #               - EncryptionEnabled
  #               - "Fn::If":
  #                   - CreateKey
  #                   - !Ref EncryptionKey
  #                   - !Ref EncryptionKeyArn
  #               - !Ref AWS::NoValue
}

resource "aws_lambda_function" "create_urls" {
  function_name = "create-urls"

  #     Properties:
  #       CodeUri: ./src
  #       Runtime: python3.6
  #       Handler: create_urls.direct_handler
  #       Role: !GetAtt CreateUrlsRole.Arn
  #       MemorySize: 1024
  #       Environment:
  #         Variables:
  #           DISABLE_OUTPUT_PARAMETERS: {"Fn::If": [OutputParametersDisabled, "true", "false"]}
  #           DISABLE_POST_ACTIONS: {"Fn::If": [PostActionsDisabled, "true", "false"]}
  #           VERBOSE: {"Fn::If": [VerboseLoggingEnabled, "true", "false"]}
  #           API_ID: !Ref Api
  #           STAGE: !Ref ApiStage
  #           KEY_ID:
  #             "Fn::If":
  #               - EncryptionEnabled
  #               - "Fn::If":
  #                   - CreateKey
  #                   - !Ref EncryptionKey
  #                   - !Ref EncryptionKeyArn
  #               - !Ref AWS::NoValue
}

resource "aws_iam_role" "process_callback" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "process_callback_sfn" {
  name = "process-callback-sfn"

  #       Roles:
  #       - !Ref ProcessCallbackRole
  #       PolicyName: AccessSfn
  #       PolicyDocument:
  #         Version: "2012-10-17"
  #         Statement:
  #           - Effect: Allow
  #             Action:
  #               - "states:SendTaskSuccess"
  #               - "states:SendTaskFailure"
  #               - "states:SendTaskHeartbeat"
  #             Resource: "*"
}

resource "aws_iam_policy" "process_callback_logs" {
  name = "process-callback-logs"

  #       Roles:
  #       - !Ref ProcessCallbackRole
  #       PolicyName: LambdaLogging
  #       PolicyDocument:
  #         Version: "2012-10-17"
  #         Statement:
  #           - Effect: Allow
  #             Action:
  #               - "logs:CreateLogStream"
  #               - "logs:CreateLogGroup"
  #             Resource: !Sub "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${ProcessCallbackFunction}:*"
  #           - Effect: Allow
  #             Action:
  #               - "logs:PutLogEvents"
  #             Resource: !Sub "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${ProcessCallbackFunction}:log-stream:*"
}

resource "aws_lambda_function" "process_callback" {
  function_name = "process-callback"

  #       CodeUri: ./src
  #       Runtime: python3.6
  #       Handler: process_callback.handler
  #       Role: !GetAtt ProcessCallbackRole.Arn
  #       MemorySize: 1024
  #       Timeout: 15
  #       Environment:
  #         Variables:
  #           DISABLE_OUTPUT_PARAMETERS: {"Fn::If": [OutputParametersDisabled, "true", "false"]}
  #           DISABLE_POST_ACTIONS: {"Fn::If": [PostActionsDisabled, "true", "false"]}
  #           VERBOSE: {"Fn::If": [VerboseLoggingEnabled, "true", "false"]}
  #           KEY_ID:
  #             "Fn::If":
  #               - EncryptionEnabled
  #               - "Fn::If":
  #                   - CreateKey
  #                   - !Ref EncryptionKey
  #                   - !Ref EncryptionKeyArn
  #               - !Ref AWS::NoValue
}

resource "aws_api_gateway_deployment" "MyDemoDeployment" {
  rest_api_id = "${aws_api_gateway_rest_api.this.id}"
  stage_name  = "test"

  variables = {
    "answer" = "42"
  }

  # depends_on = ["aws_api_gateway_integration.MyDemoIntegration"]
  #       - CreateUrlsMethod
  #       - ProcessCallbackGetMethod
  #       - ProcessCallbackPostMethod
}

resource "aws_api_gateway_stage" "this" {
  stage_name    = "v1"
  rest_api_id   = "${aws_api_gateway_rest_api.this.id}"
  deployment_id = "${aws_api_gateway_deployment.this.id}"
}

resource "aws_kms_key" "this" {
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "key-default-1",
  "Statement": [{
    "Sid": "Enable IAM User Permissions",
    "Effect": "Allow",
    "Principal": {"AWS": "arn:aws:iam::${AWS::AccountId}:root"},
    "Action": "kms:*",
    "Resource": "*"
  }]
}
EOF
}

resource "aws_iam_policy" "encryption" {
  name = "......>"

  #     Condition: EncryptionEnabled
  #     Properties:
  #       Roles:
  #       - !Ref CreateUrlsRole
  #       - !Ref ProcessCallbackRole
  #       PolicyName: AccessEncryptionKey
  #       PolicyDocument:
  #         Version: 2012-10-17
  #         Statement:
  #           - Effect: Allow
  #             Action:
  #               - "kms:GenerateDataKey"
  #               - "kms:Decrypt"
  #             Resource:
  #               "Fn::If":
  #                 - CreateKey
  #                 - !GetAtt EncryptionKey.Arn
  #                 - !Ref EncryptionKeyArn
}
