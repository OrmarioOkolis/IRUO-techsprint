#!/bin/bash
# Rusi CIJELU OpenStack TechSprint infrastrukturu (obrnuti redoslijed od
# provision.py --cloud openstack): compute-dev x N -> compute-shared -> I2 -> I3.
#
# MORA se pokretati NA RHA workstationu, u shell-u gdje je vec `source ~/admin-rc`.
# Redoslijed je bitan: I2 se rusi PRIJE I3 jer I2-in data source za I3 projekte
# se evaluira i tijekom destroy-a i puca ako projekti vise ne postoje
# (vidi CLAUDE.md "REBUILD-FROM-SCRATCH TEST").
#
#   cd ~/iruo-techsprint && bash scripts/teardown-openstack.sh
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

: "${OS_AUTH_URL:?Prvo pokreni: source ~/admin-rc}"

SSHKEY="$REPO/openstack-i2-terraform/terraform.tfvars"
SHARETYPE="techsprint-cephfs"
PREFIX="techsprint-testing"
BASE_PROJECT="${OS_PROJECT_NAME:-admin}"

scoped()  { export OS_PROJECT_NAME="$1"; export OS_PROJECT_DOMAIN_NAME="${OS_PROJECT_DOMAIN_NAME:-Default}"; unset OS_PROJECT_ID; }
unscope() { export OS_PROJECT_NAME="$BASE_PROJECT"; unset OS_PROJECT_ID; }

# 0) Regeneriraj *.auto.tfvars iz CSV-a (gitignored, dry-run NE dira infrastrukturu).
echo "### regeneriram tfvars iz CSV-a ###"
python3 scripts/provision.py --cloud openstack --csv scripts/users.csv --dry-run || {
  echo "provision.py --dry-run pao - provjeri scripts/users.csv"; exit 1;
}

# Popis developera iz auto.tfvars (id = "devNN")
DEVS=$(grep -oE 'id\s*=\s*"dev[0-9]+"' openstack-i2-terraform/csv_generated.auto.tfvars | grep -oE 'dev[0-9]+' | sort -u)
echo "### developeri: $DEVS ###"

# 1) compute-dev po developeru (zaseban state fajl, project-scoped provider)
for dev in $DEVS; do
  echo
  echo "############### destroy compute-dev $dev ###############"
  scoped "$PREFIX-$dev"
  terraform -chdir="$REPO/openstack-compute-dev-terraform" init -input=false >/dev/null
  terraform -chdir="$REPO/openstack-compute-dev-terraform" destroy -auto-approve \
    -state="terraform-$dev.tfstate" \
    -var-file="$SSHKEY" \
    -var="dev_id=$dev" \
    -var="manila_share_type=$SHARETYPE"
done

# 2) compute-shared (jump + lead), scoped na shared projekt
echo
echo "############### destroy compute-shared ###############"
scoped "$PREFIX-shared"
terraform -chdir="$REPO/openstack-compute-terraform" init -input=false >/dev/null
terraform -chdir="$REPO/openstack-compute-terraform" destroy -auto-approve -var-file="$SSHKEY"

# 3) I2 (mreze/security/portovi) - admin scope, PRIJE I3
echo
echo "############### destroy I2 (mreze) ###############"
unscope
terraform -chdir="$REPO/openstack-i2-terraform" init -input=false >/dev/null
terraform -chdir="$REPO/openstack-i2-terraform" destroy -auto-approve

# 4) I3 (projekti/korisnici/role/kvote) - admin scope, ZADNJI
echo
echo "############### destroy I3 (IAM) ###############"
unscope
terraform -chdir="$REPO/openstack-i3-terraform" init -input=false >/dev/null
terraform -chdir="$REPO/openstack-i3-terraform" destroy -auto-approve

# 5) Verifikacija
echo
echo "############### VERIFIKACIJA ###############"
unscope
echo "-- serveri (techsprint) --"
openstack server list --all-projects -f value -c Name 2>/dev/null | grep techsprint || echo "  cisto"
echo "-- mreze (techsprint) --"
openstack network list -f value -c Name 2>/dev/null | grep techsprint || echo "  cisto"
echo "-- projekti (techsprint) --"
openstack project list -f value -c Name 2>/dev/null | grep techsprint || echo "  cisto"
echo
echo "Gotovo."
