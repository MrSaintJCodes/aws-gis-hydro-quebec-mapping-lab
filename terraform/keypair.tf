# keypair.tf
resource "aws_key_pair" "main" {
  key_name   = "aws-key"
  public_key = file("../scripts/ssh/aws_key.pub")
}