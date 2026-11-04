# Sauvegardes

Chaque nuit vers 3 h 30, `make backup@run` sauvegarde tout `/srv` dans un dépôt
[restic](https://restic.net/) : chiffré, et dédupliqué (un fichier qui n'a pas changé
n'est pas recopié, une sauvegarde de plus ne coûte presque rien).

## Ce qui est sauvegardé

Tout `/srv`, donc pour chaque projet son code de déploiement, ses fichiers `.env` et
ses secrets, et ses données. Avec trois exceptions :

| Exclu | Pourquoi |
|---|---|
| `/srv/backups` | le dépôt restic lui-même, et les restaurations en cours |
| le contenu de `*/data/db` | les fichiers bruts de MariaDB : copiés pendant que la base tourne, ils peuvent être inutilisables. Les **dumps** les remplacent. |
| le contenu de `*/data/app/cache` et `*/data/app/public/legacy/cache` | caches de SuiteCRM, reconstruits automatiquement |

Seul le contenu de ces dossiers est exclu : à la restauration, ils existent, vides, avec
leur propriétaire.

Avant chaque sauvegarde, la base de **chaque conteneur MariaDB en marche** est exportée
dans `/srv/server/data/dumps/<conteneur>.sql.gz` (ex. `demo-core-db.sql.gz`), puis
sauvegardée avec le reste. Une nouvelle instance est donc prise en compte toute seule.
Les identifiants sont lus à l'intérieur du conteneur : ils ne sont ni affichés, ni
écrits sur le serveur.

## Rétention

Après chaque sauvegarde, restic garde :

- une sauvegarde par jour pendant **7 jours** ;
- une par semaine pendant **4 semaines** ;
- une par mois pendant **12 mois**.

Les autres sont supprimées, puis le dépôt est vérifié (`restic check`).

## Commandes

| Commande | Rôle |
|---|---|
| `make backup@init` | une fois par serveur : génère le mot de passe (`secrets/restic-password`) et crée le dépôt |
| `make backup@run` | sauvegarde maintenant (dumps, sauvegarde, rétention, vérification) |
| `make backup@snapshots` | liste les sauvegardes et la taille du dépôt |
| `make backup@schedule` | programme la sauvegarde chaque nuit (timer systemd `srv-backup`, demande `sudo`) |
| `make backup@logs` | journal des dernières sauvegardes et date de la prochaine |
| `make backup@restore INSTANCE=<instance> [SNAPSHOT=<id>]` | remet une instance SuiteCRM dans l'état d'une sauvegarde (par défaut la dernière), voir plus bas |

## Restaurer une instance

```bash
make backup@snapshots                          # choisir la sauvegarde (colonne ID), ou garder la dernière
make backup@restore INSTANCE=demo-core         # la dernière
make backup@restore INSTANCE=demo-core SNAPSHOT=4c1c8d60
```

La commande demande de taper le nom de l'instance pour confirmer, puis `sudo` :

1. elle extrait l'instance et le dump de sa base dans `/srv/backups/restore` : si la
   sauvegarde est incomplète, elle s'arrête sans rien toucher ;
2. elle arrête l'instance et met son dossier de côté
   (`/srv/suitecrm/<instance>.before-restore-<date>`) ;
3. elle met le dossier restauré en place, démarre MariaDB sur une base vide, importe le
   dump, puis démarre le reste et attend qu'il soit en bonne santé.

Elle affiche ensuite comment supprimer l'ancien état une fois l'instance vérifiée, ou
comment y revenir.

La restauration remet aussi la **version** de l'instance au moment de la sauvegarde
(`APP_VERSION` de `.env.local`) : code et base restent cohérents. Le prochain déploiement
la remettra à jour.

## Le mot de passe

`secrets/restic-password` chiffre toutes les sauvegardes. **Sans lui, elles sont
illisibles**, y compris pour toi. Copie-le dans ton gestionnaire de mots de passe
dès `make backup@init`, et ne le colle jamais dans un chat ni dans un dépôt.

## Limite actuelle

Les sauvegardes sont sur le même disque que le serveur : elles protègent d'une
erreur (fichier supprimé, mise à jour ratée, base abîmée), pas de la perte du
serveur. Une copie hors du serveur (stockage objet) est prévue plus tard.

## Vérifier que tout va bien

```bash
make backup@logs        # la dernière sauvegarde a-t-elle réussi ? quand est la prochaine ?
make backup@snapshots   # une sauvegarde par nuit ?
df -h /srv              # reste-t-il de la place sur le disque ?
```
