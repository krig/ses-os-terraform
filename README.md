# Deploy on ECP using Terraform

Note: ECP is an instance of Openstack running at
SUSE. This might be useful to anyone else wanting
to run Ceph on Openstack, but at least some of the
details are very specific to SUSE and SUSE Storage.

## Instructions

1. Generate a keypair to use.

        ssh-keygen

2. Create `terraform.tfvars` and put your details there:

        username = "your-username"
        password = "your-password"
        public_key = "..."
        auth_url = "..."

3. Run

        terraform init
        terraform validate
        terraform plan

4. Run

        terraform apply


