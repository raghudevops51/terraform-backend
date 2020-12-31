resource "aws_launch_template" "template" {
  name                    = var.component
  image_id                = data.aws_ami.ami.id
  instance_type           = var.INSTANCE_TYPE
  key_name                = var.KEY_NAME
  vpc_security_group_ids  = [aws_security_group.allow-component-instance.id]
  tag_specifications        {
    resource_type         = "instance"
    tags = {
      Name                = var.component
    }
  }
}

resource "aws_lb_target_group" "target-group" {
  name     = var.component
  port     = 8000
  protocol = "HTTP"
  health_check {
    path      = "/health"
  }

  vpc_id   = data.terraform_remote_state.vpc.outputs.VPC_ID
}


resource "aws_autoscaling_group" "asg" {
  name                      = var.component
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  vpc_zone_identifier       = data.terraform_remote_state.vpc.outputs.PRIVATE_SUBNETS
  target_group_arns         = [aws_lb_target_group.target-group.arn]

  launch_template {
    id                      = aws_launch_template.template.id
    version                 = "$Latest"
  }

  tag {
    key                     = "Name"
    value                   = var.component
    propagate_at_launch     = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scaleup"
  adjustment_type        = "PercentChangeInCapacity"
  policy_type            = "TargetTrackingScaling"
  estimated_instance_warmup                = "300"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 80.0
  }
}