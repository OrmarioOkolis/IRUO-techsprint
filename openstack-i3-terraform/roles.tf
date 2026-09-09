# ---------------------------------------------------------------------------
# Custom rola "techsprint_developer" - za citljivost u IAM dijagramu/auditu.
#
# VAZNA NAPOMENA (za razliku od Azure custom role_definition s popisom akcija):
# OpenStack Keystone role su samo IMENOVANE LABELE - stvarna autorizacija se
# provjerava kroz oslo.policy pravila po SVAKOM servisu (nova/neutron/cinder
# policy.json), a default RHOSP politike prepoznaju SAMO ugradjena imena rola
# (member/admin/reader), ne proizvoljna custom imena. Zato se ova custom rola
# dodjeljuje UZ ugradjenu "member" rolu u assignments.tf - "techsprint_developer"
# je oznaka/identitet, "member" je ono sto stvarno provodi self-service compute/
# network/storage prava unutar scope-a projekta developera.
#
# Fino-zrnata kontrola u stilu Azurea (npr. "smije start/stop, ne smije delete")
# bi zahtijevala izmjenu policy.json na controller0 cvoru - izvediva jer smo
# puni admin na vlastitoj classroom instanci, ali namjerno izostavljena zbog
# rizika (policy.json greska moze srusiti CIJELI RHOSP control plane, ukljucujuci
# ostatak kolegija) - projekt-scoping vec zadovoljava kljucni zahtjev zadatka
# ("programeri smiju upravljati iskljucivo svojim VM-ovima": developer nema
# nikakav pristup tudjem projektu, ne samo ogranicena prava unutar njega).
# ---------------------------------------------------------------------------
resource "openstack_identity_role_v3" "developer" {
  name = "techsprint_developer"
}

data "openstack_identity_role_v3" "member" {
  name = "member"
}

data "openstack_identity_role_v3" "admin" {
  name = "admin"
}

# ---------------------------------------------------------------------------
# "swiftoperator" - RHOSP DEFAULT Swift proxy-server.conf ima
# "operator_roles = admin, swiftoperator" - za razliku od Nova/Neutron/Cinder
# (koji prepoznaju "member" kroz oslo.policy), Swift SVOJIM VLASTITIM
# keystoneauth middlewareom zahtijeva bas jednu od te dvije role, ne "member".
# Live testirano 9.9.2026: developer s "member" rolom je dobio "Operation
# forbidden" pri pristupu VLASTITOM Swift kontejneru (preko rclone), dok je
# admin (koji vec ima "admin" rolu) uspio - potvrdjuje RHOSP default
# ponasanje. "swiftoperator" je manje-privilegirana opcija od "admin" (bez
# nje developer NE bi trebao imati potpunu Nova/Neutron kontrolu koju "admin"
# rola nosi na svom projektu), pa se dodaje kao dodatna rola SAMO za Swift
# pristup, ne zamjena za "member".
# ---------------------------------------------------------------------------
data "openstack_identity_role_v3" "swiftoperator" {
  name = "swiftoperator"
}
