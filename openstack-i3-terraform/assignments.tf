# ---------------------------------------------------------------------------
# Developer: "techsprint_developer" (brendiranje/audit) + "member" (stvarna
# prava - vidi roles.tf) SAMO na vlastitom projektu. Keystone project-scoping
# znaci da developer NE MOZE se ni autenticirati u tudji projekt - potpuna
# izolacija na IAM razini, odvojeno od mrezne izolacije u openstack-i2-terraform.
# ---------------------------------------------------------------------------
resource "openstack_identity_role_assignment_v3" "developer_branding" {
  for_each = local.developers_indexed

  user_id    = openstack_identity_user_v3.developer[each.key].id
  project_id = openstack_identity_project_v3.dev[each.key].id
  role_id    = openstack_identity_role_v3.developer.id
}

resource "openstack_identity_role_assignment_v3" "developer_member" {
  for_each = local.developers_indexed

  user_id    = openstack_identity_user_v3.developer[each.key].id
  project_id = openstack_identity_project_v3.dev[each.key].id
  role_id    = data.openstack_identity_role_v3.member.id
}

# "member" je dovoljna za Nova/Neutron/Cinder/Manila self-service, ali Swift
# SVOJIM VLASTITIM operator_roles zahtijeva "admin" ili "swiftoperator" - vidi
# opsirnu napomenu uz data.openstack_identity_role_v3.swiftoperator u roles.tf.
resource "openstack_identity_role_assignment_v3" "developer_swiftoperator" {
  for_each = local.developers_indexed

  user_id    = openstack_identity_user_v3.developer[each.key].id
  project_id = openstack_identity_project_v3.dev[each.key].id
  role_id    = data.openstack_identity_role_v3.swiftoperator.id
}

# ---------------------------------------------------------------------------
# Lead: "member" na shared projektu (vlastiti prostor za jump/lead VM) + "admin"
# na SVAKOM developer projektu (potpuna kontrola/power-state nad svim VM-ovima
# - analogno Azure "Virtual Machine Contributor" na razini cijele subscription).
# ---------------------------------------------------------------------------
resource "openstack_identity_role_assignment_v3" "lead_shared" {
  user_id    = openstack_identity_user_v3.lead.id
  project_id = openstack_identity_project_v3.shared.id
  role_id    = data.openstack_identity_role_v3.member.id
}

resource "openstack_identity_role_assignment_v3" "lead_dev_admin" {
  for_each = local.developers_indexed

  user_id    = openstack_identity_user_v3.lead.id
  project_id = openstack_identity_project_v3.dev[each.key].id
  role_id    = data.openstack_identity_role_v3.admin.id
}

# ---------------------------------------------------------------------------
# Admin operater (admin-rc) treba "admin" rolu EKSPLICITNO na shared + svakom
# dev projektu, inace ne moze dobiti project-scoped token tamo (vidi napomenu
# uz data.openstack_identity_user_v3.admin_operator u main.tf) - potreban za
# openstack-compute-terraform (Nova instance, project-scoped provider).
# ---------------------------------------------------------------------------
resource "openstack_identity_role_assignment_v3" "admin_operator_shared" {
  user_id    = data.openstack_identity_user_v3.admin_operator.id
  project_id = openstack_identity_project_v3.shared.id
  role_id    = data.openstack_identity_role_v3.admin.id
}

resource "openstack_identity_role_assignment_v3" "admin_operator_dev" {
  for_each = local.developers_indexed

  user_id    = data.openstack_identity_user_v3.admin_operator.id
  project_id = openstack_identity_project_v3.dev[each.key].id
  role_id    = data.openstack_identity_role_v3.admin.id
}
