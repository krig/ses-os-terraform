variable "username" {
  description = "Username"
}

variable "password" {
  description = "Password"
}

variable "auth_url" {
  description = "Openstack auth URL"
}

variable "public_key" {
  description = "Public key for keypair to use when connecting"
}

provider "openstack" {
  user_name           = var.username
  password            = var.password
  auth_url            = var.auth_url
  region              = "CustomRegion"
  tenant_name         = "ses"
  project_domain_name = "default"
  user_domain_name    = "ldap_users"
  cacert_file         = "/usr/share/pki/trust/anchors/SUSE_Trust_Root.crt.pem"
}

variable "workers" {
  default = 4
}

resource "openstack_compute_keypair_v2" "my-cloud-key" {
  name       = format("%s-key", var.username)
  public_key = var.public_key
}

resource "openstack_networking_network_v2" "ceph_network" {
  name           = format("%s-network", var.username)
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "ceph_subnet" {
  name       = format("%s-subnet", var.username)
  network_id = openstack_networking_network_v2.ceph_network.id
  cidr       = "192.168.199.0/24"
  ip_version = 4
}

resource "openstack_compute_secgroup_v2" "open_ssh" {
  name        = "open_ssh"
  description = "Open port for SSH"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "open_ceph" {
  name        = "open_ceph"
  description = "Open ports for ceph"

  rule {
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 443
    to_port = 443
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 875
    to_port = 875
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 2049
    to_port = 2049
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 2379
    to_port = 2379
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 3260
    to_port = 3260
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 6789
    to_port = 6789
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 8472
    to_port = 8472
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 2379
    to_port = 2380
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 3000
    to_port = 3000
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 8080
    to_port = 8081
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 4149
    to_port = 4149
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 6800
    to_port = 7300
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 9090
    to_port = 9128
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 8285
    to_port = 8285
    ip_protocol = "udp"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_networking_port_v2" "ceph_port" {
  name               = format("%s-port", var.username)
  network_id         = openstack_networking_network_v2.ceph_network.id
  admin_state_up     = "true"
  security_group_ids = [
    openstack_compute_secgroup_v2.open_ssh.id,
    openstack_compute_secgroup_v2.open_ceph.id
  ]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.ceph_subnet.id
  }
}

resource "openstack_blockstorage_volume_v2" "osd" {
  name = format("%s-osd-%02d", var.username, count.index + 1)
  size = 10
  count = var.workers
}

resource "openstack_compute_instance_v2" "ses" {
  count      = var.workers
  name       = format("%s-instance-%02d", var.username, count.index + 1)
  image_name = "minimal-sle-15.1-x86_64"
  flavor_name= "m1.small"
  key_pair   = openstack_compute_keypair_v2.my-cloud-key.name

  security_groups = [
    "default",
    openstack_compute_secgroup_v2.open_ssh.name,
    openstack_compute_secgroup_v2.open_ceph.name
  ]

  network {
    name = openstack_networking_network_v2.ceph_network.name
  }

  depends_on = [openstack_networking_subnet_v2.ceph_subnet]
}

resource "openstack_compute_volume_attach_v2" "attached" {
  count = var.workers
  instance_id = element(openstack_compute_instance_v2.ses.*.id, count.index)
  volume_id   = element(openstack_blockstorage_volume_v2.osd.*.id, count.index)
}

resource "openstack_compute_floatingip_v2" "fip" {
  count = var.workers
  pool = "floating"
}

resource "openstack_compute_floatingip_associate_v2" "ceph_floating" {
  count = var.workers
  floating_ip = element(openstack_compute_floatingip_v2.fip.*.address, count.index)
  instance_id = element(openstack_compute_instance_v2.ses.*.id, count.index)
}

