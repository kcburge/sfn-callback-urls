# Outputs:
#   Api:
#     Value: !Sub "https://${Api}.execute-api.${AWS::Region}.amazonaws.com/${ApiStage}"
#   Function:
#     Value: !Ref CreateUrls
#   Policy:
#     Value: !Ref CreateUrlsPolicy
