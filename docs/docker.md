# Nettoyage des images Docker

Chaque release de SuiteCRM laisse une image d'environ 1,7 Go sur le serveur, et
Dependabot en ajoute (MariaDB, Mailpit…). `make docker@prune` retire chaque dimanche
celles dont personne n'a plus besoin.

## Ce qui est gardé

Pour chaque dépôt d'images (`ghcr.io/…/suitecrm-core`, `mariadb`, `restic/restic`…) :

- les **2 tags les plus récents** (`DOCKER_KEEP`) : la version en service et la
  précédente, pour un retour arrière ;
- **toute image utilisée par un conteneur**, démarré ou arrêté, quel que soit son âge.

Sont retirés : les autres tags, les images sans nom (restes de mises à jour) et le cache
de build (rien n'est construit sur le serveur). Les conteneurs, les volumes et `/srv` ne
sont jamais touchés.

Si un retour arrière vise une version déjà retirée, Docker la retélécharge depuis le
registre au démarrage : le nettoyage ne l'empêche pas, il le rallonge d'une minute.

## Commandes

| Commande | Rôle |
|---|---|
| `make docker@prune DRY_RUN=1` | liste ce qui serait gardé et retiré, sans rien retirer |
| `make docker@prune` | nettoie maintenant |
| `make docker@schedule` | une fois par serveur : nettoyage chaque dimanche vers 4 h 30, après la sauvegarde (demande `sudo`) ; relançable sans risque |
| `make docker@logs` | journal des derniers nettoyages et prochain passage |
