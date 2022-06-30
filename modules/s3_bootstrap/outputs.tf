/*
output bucket_name {
  value = aws_s3_bucket.bootstrap.id
}
*/

output instance_profile {
  value = aws_iam_instance_profile.main.0.id
}