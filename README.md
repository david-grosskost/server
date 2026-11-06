# server

Administration du serveur qui héberge les projets (`/srv`), à part du code des projets eux-mêmes.
Pour l'instant : les **sauvegardes** de tout `/srv`, chaque nuit, avec
[restic](https://restic.net/), et le **pare-feu SMTP** : seules les instances de prod
peuvent envoyer des e-mails vers l'extérieur.

| Dossier du serveur | Contenu |
|---|---|
| `/srv/reverse-proxy` | Traefik, CrowdSec (dépôt `reverse-proxy`) |
| `/srv/suitecrm/<instance>` | une instance SuiteCRM (démo, prod…), déployée par la CI |
| `/srv/server` | ce dépôt : scripts de sauvegarde, dumps des bases |
| `/srv/backups/restic` | le dépôt restic : les sauvegardes elles-mêmes |

## Prérequis

- un serveur Linux avec systemd, Docker (28 ou plus), Git et `make`
- un utilisateur membre du groupe `docker`, avec `sudo`

restic tourne dans Docker, dans une version fixée : rien d'autre à installer.

## Installation

```bash
sudo mkdir -p /srv/server && sudo chown "$USER": /srv/server
git clone https://github.com/<compte>/server.git /srv/server
cd /srv/server
make backup@init       # mot de passe + dépôt restic
make backup@run        # première sauvegarde
make backup@schedule   # puis chaque nuit
make firewall@install  # SMTP sortant réservé aux instances de prod
make firewall@test
make docker@schedule   # nettoyage des images Docker chaque dimanche
```

`make` sans argument liste toutes les commandes disponibles.

## Documentation

| Page | Contenu |
|---|---|
| [Sauvegardes](docs/sauvegardes.md) | ce qui est sauvegardé, rétention, commandes, vérifications |
| [Pare-feu SMTP](docs/pare-feu.md) | e-mails sortants réservés à la prod, commandes, vérifications |
| [Images Docker](docs/docker.md) | nettoyage hebdomadaire : ce qui est gardé, commandes |

## Développement

```bash
make git@hooks   # active les hooks Git (messages de commit, scripts, secrets)
```

Les messages de commit suivent [Conventional Commits](https://www.conventionalcommits.org/fr/).
