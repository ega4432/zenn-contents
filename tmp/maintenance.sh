#!/bin/sh -eu
PS3="Select which one to switch to maintenance mode: "
start="start"
end="end"

select MODE in "$start" "$end"
do
  if [ -z "$MODE" ]; then
    echo "\033[31mERROR\033[m: The selected option is invalid.\n"
    continue
  else
    break
  fi
done

echo You selected $REPLY\) $MODE"\n"

# S3 バケット名、CloudFront ディストリビューション ID
S3_BUCKET=example.com
DISTRIBUTION_ID=E1A2B3C4D5F6G7

# メンテナンスモードに切り替える場合
if [ $MODE = "start" ]; then
  SERVICE_UNAVAILABLE_RESPONSE=$(cat << EOS
{
  "ErrorCode" : 403,
  "ResponsePagePath": "/maintenance.html",
  "ResponseCode": "503",
  "ErrorCachingMinTTL": 0
}
EOS
  )
  aws s3 cp src/maintenance.html s3://${S3_BUCKET}/dist/maintenance.html --acl public-read

# メンテナンスモードを終了する場合
else
  SERVICE_UNAVAILABLE_RESPONSE=$(cat << EOS
{
  "ErrorCode" : 403,
  "ResponsePagePath": "/index.html",
  "ResponseCode": "404",
  "ErrorCachingMinTTL": 0
}
EOS
  )
  aws s3 rm s3://${S3_BUCKET}/dist/maintenance.html
fi

# 現在の Web ディストリビューション構成を JSON として出力し、メンテナンスモード用に整形
aws cloudfront get-distribution-config --id ${DISTRIBUTION_ID} | jq '.' > ./bin/dist.json
cat ./bin/dist.json | \
  jq '. |= .+ {"IfMatch": .ETag}
    | del(.ETag)
    | .DistributionConfig.CustomErrorResponses.Items |= map((select(.ErrorCode == 403) |= '"${SERVICE_UNAVAILABLE_RESPONSE}"') // .)
    | (.DistributionConfig.WebACLId |= (
    if "'${MODE}'" == "start" then "arn:aws:wafv2:us-east-1:123456789010:global/webacl/maintenance/ab123456-7890-123a-bd45-6789efghijklmn"
    else ""
    end))' \
    > tmp.json && \
  mv tmp.json ./bin/dist.json

# CloudFront ディストリビューションを更新
aws cloudfront update-distribution --cli-input-json file://bin/dist.json --id ${DISTRIBUTION_ID} > ./bin/result.json
rm -f tmp.json

# キャッシュ削除
aws cloudfront create-invalidation --distribution-id ${DISTRIBUTION_ID} --path '/*'

