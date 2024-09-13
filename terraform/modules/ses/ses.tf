resource "aws_ses_domain_identity" "master_email_domain" {
  domain = var.domain_name

}

resource "aws_route53_record" "ses_record_verification" {
  zone_id = var.zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.master_email_domain.verification_token]
}

resource "aws_ses_domain_dkim" "master_dkim" {
  domain = aws_ses_domain_identity.master_email_domain.domain
}

resource "aws_ses_domain_identity_verification" "bahmni_verification" {
  domain = aws_ses_domain_identity.master_email_domain.id

  depends_on = [aws_route53_record.ses_record_verification]
}

resource "aws_route53_record" "ses_verification_records" {
  count   = 3
  zone_id = var.zone_id
  name    = "${element(aws_ses_domain_dkim.master_dkim.dkim_tokens, count.index)}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.master_dkim.dkim_tokens, count.index)}.dkim.amazonses.com"]
}
