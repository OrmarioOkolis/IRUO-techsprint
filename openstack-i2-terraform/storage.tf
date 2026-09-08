# ---------------------------------------------------------------------------
# Datotecna pohrana (backupi) po developeru preko Manila (NFS share) - stvarni
# OpenStack servis, potvrdjeno dostupan na RHA sandboxu (manila/manilav2 u
# service list). MinIO/NFS-VM fallback iz projektne strategije NIJE potreban.
#
# NAMJERNO NIJE OVDJE: openstack_sharedfilesystem_share_v2 i _sharenetwork_v2
# imaju project_id kao COMPUTED-ONLY atribut (za razliku od Neutron/LB resursa
# u network.tf/loadbalancer.tf gdje je tenant_id stvarno postavljiv preko
# admin-scoped providera) - potvrdjeno preko `terraform providers schema -json`
# (optional=None, computed=True). Admin ne moze kreirati Manila share "u ime"
# drugog projekta ovim resursom - nastao bi u admin-ovom vlastitom projektu,
# ne u dev projektu, sto krsi izolaciju.
#
# Zato Manila share ide u ISTI project-scoped compute modul kao Nova instance/
# Cinder volumeni/Swift kontejneri (vidi napomenu u compute.tf - taj modul jos
# nije napisan, CSV provisioning skripta ce ga primjenjivati jednom po
# developeru, s OS_PROJECT_NAME prebacenim na tog developera prije svakog
# apply-a).
# ---------------------------------------------------------------------------
