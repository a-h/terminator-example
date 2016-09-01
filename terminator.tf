# This terraform configuration requires the `aws configure` command to be executed
# and for the user to have the following permissions policies attached:
# - EC2FullAccess,
# - IAMFullAccess,
# - AmazonS3FullAccess,
# - AmazonVPCFullAccess

provider "aws" {
    region = "eu-west-1"
}

resource "aws_key_pair" "terminator_key_pair" {
  key_name = "terminator_key_pair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1AIlCUiSzn8G4bTjba6vcsSYO26m5DB77vPTqB45p6z55jpz+ZF3pZ2Yn2bqw+0BoU/FwnqzRtW0GHHMoF6A5VUb0UbuGU2buQzaLQGtuDRNhvdUKCfQJo0eTZ4lZ0mAtVnGkJhbwYAaXIuTpSc9rZw1HJOjgZNJgX9eLjWtg5xqR+iVF8nmUY8FA6NeEvKYqFvYK+KCmCyUryjtnSqbv1AGOlb0QFL2YTd/SZO/0lwoxDpQkBk+JS8MN2pkwceXcEFbbds6KjHKdg7vb7u1lxuyJ8t1EbfIrLBTcK5U0U6ZhjUJ0ZRqWo+Zmxfs1PjH0p1QezWC3hcPwwLkOhZPx vagrant@localhost.localdomain"
}

# Create a VPC
resource "aws_vpc" "terminator_vpc" {
    cidr_block = "10.5.0.0/16" # 10.5.0.0-10.4.255.255
    tags {
        Name = "terminator_vpc"
    }
}

# Create a security group within the VPC which allows incoming access to the Web Servers.
resource "aws_security_group" "terminator_ssh_access" {
    name = "terminator_ssh_access"
    description = "Allow inbound SSH traffic on port 22"
    vpc_id = "${aws_vpc.terminator_vpc.id}"

    # Allow SSH from everywhere.
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow all outgoing traffic.
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags {
      Name = "terminator_ssh_access"
    }
}

resource "aws_security_group" "terminator_rdp_access" {
    name = "terminator_rdp_access"
    description = "Allow inbound RDP traffic on port 3389"
    vpc_id = "${aws_vpc.terminator_vpc.id}"

    ingress {
        from_port = 3389
        to_port = 3389
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags {
      Name = "terminator_rdp_access"
    }
}

resource "aws_security_group" "terminator_web_access" {
  name = "terminator_web_access"
  description = "Allow inbound HTTP traffic"
  vpc_id = "${aws_vpc.terminator_vpc.id}"

  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outgoing traffic.
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "terminator_web"
  }
}

# Create an Internet gateway to route traffic to the Web servers.
resource "aws_internet_gateway" "terminator_gateway" {
    vpc_id = "${aws_vpc.terminator_vpc.id}"

    tags {
        Name = "terminator_gateway"
    }
}

# Grant the VPC Internet access on its main route table
resource "aws_route" "terminator_internet_access" {
  route_table_id         = "${aws_vpc.terminator_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.terminator_gateway.id}"
}

# Create a public subnet in the "terminator" VPC for each availability zone.
resource "aws_subnet" "terminator_subnet" {
    vpc_id = "${aws_vpc.terminator_vpc.id}"
    cidr_block = "10.5.129.0/24" # 10.5.129.0 - 10.5.129.255
    map_public_ip_on_launch = true
    availability_zone = "eu-west-1a"
    tags {
      Name = "terminator_subnet"
    }
}

# Setup an auto scaling group for the development environment.
resource "aws_autoscaling_group" "terminator_asg_web" {
  lifecycle { create_before_destroy = true }

  # Spread the app instances across the availability zones
  availability_zones = ["eu-west-1a"]

  name = "terminator_asg_web"
  max_size = 3
  min_size = 3
  desired_capacity = 3
  health_check_grace_period = 900 # 15 minutes, because Windows can take a long time to start...
  health_check_type = "ELB"
  launch_configuration = "${aws_launch_configuration.terminator_lc_web.id}"
  load_balancers = ["${aws_elb.terminator_web_elb.id}"]
  vpc_zone_identifier = ["${aws_subnet.terminator_subnet.id}"]
  wait_for_capacity_timeout = 0

  tag {
    key = "Name"
    value = "terminator_asg_web"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "terminator_lc_web" {
    # Switch to "ami-7de87d0e" for Windows.
    image_id = "ami-f9dd458a"

    instance_type = "t2.small"
    key_name = "terminator_key_pair"

    security_groups = [
      "${aws_security_group.terminator_web_access.id}",
      "${aws_security_group.terminator_rdp_access.id}",
      "${aws_security_group.terminator_ssh_access.id}"
    ]
    name_prefix = "terminator_lc_web"

    # Switch to web_setup.ps for Windows!
    user_data = "${file("web_setup.sh")}"

    lifecycle { create_before_destroy = true }
}

# Setup load balancers.
resource "aws_elb" "terminator_web_elb" {
  name = "terminator-web-elb"
  subnets = [
    "${aws_subnet.terminator_subnet.id}",
  ]
  security_groups = [ "${aws_security_group.terminator_web_access.id}" ]

  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 8
    timeout = 3
    target = "HTTP:80/Version"
    interval = 10
  }

  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400

  tags {
    Name = "terminator-web-elb"
  }
}

resource "aws_s3_bucket" "terminator_build" {
    bucket = "terminator-build"
    acl = "public-read"
    versioning {
            enabled = true
    }
    tags {
        Name = "terminator-build"
    }
}

resource "aws_security_group" "terminator_aws_lambda_sg" {
    name = "terminator_aws_lambda_sg"
    description = "Allow outbound connections."
    vpc_id = "${aws_vpc.terminator_vpc.id}"

    # Allow all outgoing traffic.
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags {
      Name = "terminator_aws_lambda_sg"
    }
}

resource "aws_iam_role" "iam_for_lambda" {
    name = "iam_for_lambda"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "terminator_lambda_policy" {
  name = "terminator_lambda_policy"
  role = "${aws_iam_role.iam_for_lambda.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Resource": "*",
        "Action": [
            "ec2:DescribeInstances",
            "ec2:CreateNetworkInterface",
            "ec2:AttachNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "autoscaling:CompleteLifecycleAction"
        ]
    }
  ]
}
EOF
}

resource "aws_lambda_function" "terminate_instance_on_new_release" {
    filename = "terminate_instance_on_new_release.zip"
    function_name = "terminate_instance_on_new_release"
    role = "${aws_iam_role.iam_for_lambda.arn}"
    handler = "index.handler"
    source_code_hash = "${base64sha256(file("terminate_instance_on_new_release.zip"))}"
    timeout = 300
    vpc_config {
        subnet_ids = ["${aws_subnet.terminator_subnet.id}"]
        security_group_ids = ["${aws_security_group.terminator_aws_lambda_sg.id}"]
    }
}

resource "aws_lambda_function" "terminate_old_versions" {
    filename = "terminate_old_versions.zip"
    function_name = "terminate_old_versions"
    role = "${aws_iam_role.iam_for_lambda.arn}"
    handler = "index.handler"
    source_code_hash = "${base64sha256(file("terminate_old_versions.zip"))}"
    timeout = 300
    vpc_config {
        subnet_ids = ["${aws_subnet.terminator_subnet.id}"]
        security_group_ids = ["${aws_security_group.terminator_aws_lambda_sg.id}"]
    }
}