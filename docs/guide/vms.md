# 3. Talos VMs

This step uses Terraform to create six empty VMs (one control plane and
one worker on each node). Each VM boots the Talos installer ISO. Terraform
does not configure Talos. The full reference is
[`development/terraform/README.md`](https://github.com/nikpcenicni/Nikflix/blob/main/development/terraform/README.md).

## Create a Proxmox API token

Create a user and token for Terraform. Do not use `root@pam`.

```sh
ssh root@192.168.10.10 '
  pveum user add terraform@pve
  pveum role add Terraform -privs "VM.Allocate VM.Config.CPU VM.Config.Memory VM.Config.Disk VM.Config.Network VM.Config.HWType VM.Config.Options VM.Config.CDROM VM.Config.Cloudinit VM.Console VM.PowerMgmt VM.Audit Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit SDN.Use Sys.Audit"
  pveum aclmod / -user terraform@pve -role Terraform
  pveum user token add terraform@pve terraform --privsep 0
'
```

Save the token value in your password manager. Proxmox shows it only once.

!!! note
    The privilege list above is a starting point. If `terraform apply`
    fails with a permission error, add the privilege it names to the role.

## Apply

```sh
cd development/terraform
cp terraform.tfvars.example terraform.tfvars     # set proxmox_endpoint
export TF_VAR_proxmox_api_token='terraform@pve!terraform=<uuid>'
terraform init
terraform plan
terraform apply
terraform output talos_vms
```

## Check

In the Proxmox GUI, VMs 201-206 exist and are running. Each VM console
shows Talos in maintenance mode with an IP address from DHCP.

!!! warning "Terraform state is local"
    `*.tfstate` is git-ignored and lives only on the workstation that ran
    `terraform apply`. Back up `development/terraform/terraform.tfstate`,
    or be ready to [import or recreate the VMs](../disaster-recovery.md#terraform-state-is-lost).

!!! note "Change for your lab"
    VM sizes, IDs, nodes, and planned IPs are in
    `development/terraform/locals.tf`. Storage pool and bridge names are
    variables in `variables.tf`.
