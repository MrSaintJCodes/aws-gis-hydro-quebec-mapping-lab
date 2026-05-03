resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_policy" "opengis_artifacts_read" {
  name = "${var.project_name}-artifacts-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.opengis_artifacts.arn,
          "${aws_s3_bucket.opengis_artifacts.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "opengis_artifacts_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.opengis_artifacts_read.arn
}
