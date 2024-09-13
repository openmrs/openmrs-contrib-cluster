data "aws_iam_policy_document" "ses_send_email_access_policy" {
  statement {
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]

    resources = [
      aws_ses_domain_identity.master_email_domain.arn
    ]
  }
}
