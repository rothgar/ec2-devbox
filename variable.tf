variable "EC2_INSTANCE_NAME" {
  type    = string
  default = "devbox"
  description = "Name for the instance"
}
variable "EC2_INSTANCE_SIZE" {
  type    = string
  default = "c5.4xlarge"
  description = "The EC2 instance size"
}
variable "EC2_ROOT_VOLUME_SIZE" {
  type    = string
  default = "100"
  description = "The volume size for the root volume in GiB"
}
variable "EC2_ROOT_VOLUME_TYPE" {
  type    = string
  default = "gp3"
  description = "The type of data storage: standard, gp2, io1"
}
variable "EC2_ROOT_VOLUME_DELETE_ON_TERMINATION" {
  default = true
  description = "Delete the root volume on instance termination."
}
variable "AWS_REGION" {
    type = string
    default = "us-west-2"
    description = "Region where to create the instance."
}