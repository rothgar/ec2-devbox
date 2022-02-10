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

variable "key_name" {}

resource "tls_private_key" "devbox" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.devbox.public_key_openssh
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
  iam_instance_profile = "${var.EC2_INSTANCE_NAME}"
  key_key_name = devbox

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

  provisioner "local-exec" {
    command = "echo ${self.id} >> INSTANCE_ID.txt"
  }
}

resource "local_file" "foo" {
    content     = tls_private_key.devbox.private_key_pem
    file_permission = "0600"
    filename = "~/.ssh/devbox.pem"
}

output "instance-id" {
  value = aws_instance.dev_instance.id
}