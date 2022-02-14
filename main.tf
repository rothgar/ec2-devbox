terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider aws {
  region = "${var.AWS_REGION}"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.EC2_INSTANCE_NAME}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "dev_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "${var.EC2_INSTANCE_SIZE}"
  associate_public_ip_address = false
  # need to create an instance profile
  iam_instance_profile = "${var.EC2_INSTANCE_NAME}"
  key_name = "${var.EC2_INSTANCE_NAME}"

  root_block_device {
    volume_size           = "${var.EC2_ROOT_VOLUME_SIZE}"
    volume_type           = "${var.EC2_ROOT_VOLUME_TYPE}"
    delete_on_termination = "${var.EC2_ROOT_VOLUME_DELETE_ON_TERMINATION}"
  }

  tags = {
    Name = "${var.EC2_INSTANCE_NAME}"
  }

  user_data = <<EOF
#!/bin/bash
set -x

curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
dpkg -i session-manager-plugin.deb

apt install -y zsh

useradd -s /bin/zsh -m ssm-user
echo "ssm-user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ssm-user

# Add our SSH keys from GitHub
sudo -u ssm-user -- ssh-import-id gh:rothgar

# set CI for automated brew install
# export CI=1 HOME=/home/ssm-user
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' > /home/ssm-user/.zshrc

apt remove --purge snapd
# block snapd
cat << EOC > /etc/apt/preferences.d/snapd
Package: snapd
Pin: origin *
Pin-Priority: -1
EOC

EOF
}

resource "local_file" "ssh_key_file" {
    content     = tls_private_key.ssh_key.private_key_pem
    file_permission = "0600"
    filename = "${var.EC2_INSTANCE_NAME}.pem"
}

# resource "local_file" "ssh_config" {
#   filename = "${var.EC2_INSTANCE_NAME}.config"
#   content = <<- EOT
#   Host "${var.EC2_INSTANCE_NAME}"
#     HostName "${aws_instance.dev_instance.id}"
#     StrictHostKeyChecking no
#     IdentityFile "${local_file.ssh_key_file.filename}"
#     UserKnownHostsFile=/dev/null
#     User ubuntu
#     ProxyCommand bash --login -c "/home/linuxbrew/.linuxbrew/bin/aws ssm start-session --target $(echo %h|cut -d'.' -f1) --profile work --region us-west-2 --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
# EOT
# }

resource "local_file" "instance_file" {
    content  = aws_instance.dev_instance.id
    filename = "INSTANCE_ID.txt"
}

output "instance-id" {
  value = aws_instance.dev_instance.id
}
