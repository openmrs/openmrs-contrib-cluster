resource "aws_iam_user" "ses_user" {
  name = "bahmni-ses-user"
}

resource "aws_iam_policy" "ses_send_email_access" {
  policy = data.aws_iam_policy_document.ses_send_email_access_policy.json
}

resource "aws_iam_user_policy_attachment" "attach_ses_policy" {
  policy_arn = aws_iam_policy.ses_send_email_access.arn
  user       = aws_iam_user.ses_user.id
}

resource "aws_iam_access_key" "ses" {
  user = aws_iam_user.ses_user.id
}

resource "aws_ssm_parameter" "smtp_access_key" {
  name  = "/smtp/access_key"
  type  = "SecureString"
  value = aws_iam_access_key.ses.id
}

resource "aws_ssm_parameter" "smtp_access_secret" {
  name  = "/smtp/secret"
  type  = "SecureString"
  value = aws_iam_access_key.ses.ses_smtp_password_v4
}
