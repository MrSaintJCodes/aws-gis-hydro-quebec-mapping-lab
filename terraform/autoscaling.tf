resource "aws_autoscaling_group" "opengis" {
  name = "${local.name}-asg"

  min_size         = var.asg_min_size
  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size

  vpc_zone_identifier = aws_subnet.private_app[*].id

  health_check_type         = "ELB"
  health_check_grace_period = 600

  target_group_arns = [aws_lb_target_group.opengis.arn]

  launch_template {
    id      = aws_launch_template.opengis.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-app"
    propagate_at_launch = true
  }
}