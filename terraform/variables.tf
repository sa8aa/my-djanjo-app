variable "aws_region"   { default = "us-east-1" }
variable "app_name"     { default = "django-app" }
variable "db_name"      { default = "mydb" }
variable "db_user"      { default = "myuser" }
variable "db_password"  { sensitive = true }
