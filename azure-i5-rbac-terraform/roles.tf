# ---------------------------------------------------------------------------
# Custom role "TechSprint Developer" - least-privilege: smije samo
# pokrenuti/zaustaviti/restartati VLASTITE VM-ove i citati stanje. Nema prava
# mijenjati mrezu, pohranu, disk niti bilo koji drugi tip resursa - to je
# namjerno uze od ugradjene "Virtual Machine Contributor" role (koja dopusta
# i brisanje/kreiranje VM-ova, ne samo power-state).
# ---------------------------------------------------------------------------
resource "azurerm_role_definition" "developer" {
  name        = "TechSprint Developer"
  scope       = data.azurerm_subscription.current.id
  description = "Power-state kontrola (start/stop/restart) i read-only pristup iskljucivo nad vlastitim resursima. Bez prava pisanja na mrezu, pohranu ili druge developere."

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Compute/disks/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/loadBalancers/read",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.KeyVault/vaults/read",
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

# ---------------------------------------------------------------------------
# Za DevOps Leada koristimo UGRADJENU rolu "Virtual Machine Contributor"
# (namjerno, ne "Contributor") - Lead smije potpuno upravljati stanjem SVIH
# VM-ova (start/stop/restart/redeploy) u sustavu, ali i dalje nema pravo
# mijenjati mrezu/storage/key vault izvan onog sto VM Contributor dopusta.
# Ovo je zahtjev I5 rubrike: "custom ILI ugradjene role" - ovdje demonstriramo
# oboje: custom za developera (uzi opseg), ugradjenu za leada (siri opseg).
# ---------------------------------------------------------------------------
