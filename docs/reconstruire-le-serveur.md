# Reconstruire le serveur

Ce qu'il faut faire pour remonter un VPS neuf jusqu'à des instances SuiteCRM restaurées,
par exemple après la perte du serveur. Tout ce qui est dans `/srv` vient des dépôts et des
sauvegardes ; cette page couvre **le reste** : système, utilisateurs, SSH, Docker, pare-feu,
GitHub et DNS. Relevé de l'existant le 6 novembre 2026.

| Élément | État actuel |
|---|---|
| Système | Ubuntu 26.04 LTS (VPS OVHcloud, 4 vCores, 8 Go), mises à jour de sécurité automatiques |
| Utilisateurs | `ubuntu` (administration, `sudo`, groupe `docker`) ; `deploy` (déploiements de la CI, groupe `docker`, sans `sudo`) |
| SSH | port 22, clés uniquement, pas de connexion `root` |
| Pare-feu de l'hôte | `ufw` : SSH, 80 et 443 |
| Docker | Docker CE 29 et Compose 5, du dépôt officiel de Docker ; journaux des conteneurs limités à 3 × 10 Mo |
| Services `srv-*` | `srv-backup.timer` (sauvegarde, 3 h 30), `srv-firewall` (SMTP sortant), `srv-docker-prune.timer` (nettoyage, dimanche) |

## 0. Ce qui doit exister hors du serveur

Sans ces éléments, la reconstruction est impossible ou incomplète. À garder dans le
gestionnaire de mots de passe :

| Élément | Où il sert |
|---|---|
| **Le mot de passe restic** (`/srv/server/secrets/restic-password`) | relire les sauvegardes : sans lui, elles sont illisibles |
| Les identifiants de l'API OVH (Application key, secret, consumer key) | certificat `*.david-grosskost.fr` (reverse-proxy) |
| L'adresse de signal Healthchecks.io du contrôle `srv-backup` | alerte de la sauvegarde nocturne |
| La clé SSH privée de chaque poste | se connecter au serveur |

> **Limite actuelle** : les sauvegardes sont sur le disque du serveur. Si le VPS est
> perdu, elles le sont aussi : on reconstruit alors le serveur à vide, puis les démos
> se rechargent avec le workflow Seed. La copie des sauvegardes hors du serveur est le
> prochain chantier ; une fois en place, l'étape 9 restaure aussi les données.

## 1. Commander le VPS

Chez OVHcloud : **Ubuntu 26.04 LTS**, avec la clé SSH publique du poste. On se connecte
en `ubuntu` :

```bash
ssh ubuntu@<nouvelle-adresse>
```

## 2. Système

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y git make unattended-upgrades
sudo dpkg-reconfigure -f noninteractive unattended-upgrades   # mises à jour de sécurité automatiques
sudo hostnamectl set-hostname vps-david-grosskost
```

## 3. SSH

Les clés des autres postes, dans `~/.ssh/authorized_keys` de `ubuntu` (une par ligne,
nommées d'après le poste : `pc-fixe-perso`, `pc-dell-pro`…). Puis, **en gardant la session
ouverte** jusqu'à ce qu'une nouvelle connexion ait réussi :

```bash
sudo tee /etc/ssh/sshd_config.d/10-durcissement.conf >/dev/null <<'CONF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
CONF
sudo sshd -t && sudo systemctl reload ssh
```

## 4. Pare-feu de l'hôte

SSH en premier, sinon la session se coupe :

```bash
sudo ufw allow OpenSSH && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
sudo ufw enable
```

## 5. Docker

Depuis le dépôt officiel de Docker (pas le paquet `docker.io` d'Ubuntu), en suivant
https://docs.docker.com/engine/install/ubuntu/. Puis :

```bash
sudo usermod -aG docker ubuntu
sudo tee /etc/docker/daemon.json >/dev/null <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
JSON
sudo systemctl restart docker
```

Se déconnecter et se reconnecter, puis vérifier : `docker ps` sans `sudo`.

## 6. `/srv` et l'utilisateur `deploy`

```bash
sudo mkdir -p /srv/reverse-proxy /srv/server /srv/suitecrm
sudo chown ubuntu: /srv/reverse-proxy /srv/server
sudo adduser --disabled-password --gecos "" deploy
sudo usermod -aG docker deploy
sudo chown deploy: /srv/suitecrm
```

La CI se connecte en `deploy` avec une clé à part (`github-actions-deploy@suitecrm-core`),
dont la partie privée est le secret `DEPLOY_SSH_KEY` du dépôt suitecrm-core. On remet sa
partie publique, avec l'option `restrict` (pas de redirection de ports, pas de terminal
interactif) :

```bash
sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
echo 'restrict ssh-ed25519 AAAA… github-actions-deploy@suitecrm-core' \
  | sudo tee /home/deploy/.ssh/authorized_keys >/dev/null
sudo chown deploy: /home/deploy/.ssh/authorized_keys && sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

La partie publique est dans le gestionnaire de mots de passe, ou se recalcule depuis la
privée (`ssh-keygen -y -f <clé>`). Si elle est perdue : générer une nouvelle paire
(`ssh-keygen -t ed25519 -C github-actions-deploy@suitecrm-core`), mettre la privée dans
le secret `DEPLOY_SSH_KEY` et la publique ici.

## 7. DNS et GitHub, si l'adresse a changé

1. **DNS** (zone OVH) : l'enregistrement `A *.david-grosskost.fr` pointe vers la nouvelle
   adresse. Pas d'AAAA.
2. **GitHub**, dépôt suitecrm-core → Settings → Environments → `demo` (et `production`) :
   - `DEPLOY_HOST` : la nouvelle adresse ;
   - `DEPLOY_KNOWN_HOSTS` : l'empreinte du nouveau serveur, sinon la CI refuse de s'y
     connecter. Depuis un poste :

     ```bash
     ssh-keyscan -t ed25519 <nouvelle-adresse>
     ```

Même adresse (VPS réinstallé) : seule `DEPLOY_KNOWN_HOSTS` change, la clé du serveur étant
nouvelle.

## 8. Reverse-proxy, puis ce dépôt

```bash
git clone https://github.com/david-grosskost/reverse-proxy.git /srv/reverse-proxy
cd /srv/reverse-proxy && make app@install APP_ENV=prod   # demande les identifiants OVH

git clone https://github.com/david-grosskost/server.git /srv/server
cd /srv/server
install -d -m 700 secrets
( umask 077 && read -r -s -p "Mot de passe restic : " p && printf '%s\n' "$p" > secrets/restic-password ); echo
make backup@init        # garde ce mot de passe ; crée le dépôt s'il n'existe pas
make backup@schedule
make backup@alert       # l'adresse Healthchecks.io
make firewall@install && make firewall@test
make docker@schedule
```

Remettre le mot de passe restic **avant** `make backup@init` : sinon un nouveau est
généré, et une copie des anciennes sauvegardes ne serait plus lisible.

## 9. Les instances SuiteCRM

1. **Redéployer** chaque instance depuis GitHub : dépôt suitecrm-core → Actions →
   **Deploy** → Run workflow, « Use workflow from » sur le tag de la version voulue (ex.
   `v0.12.2`), environnement `demo`. Le premier déploiement crée l'instance, ses mots de
   passe, et l'installe.
2. **Les données** :
   - une démo : Actions → **Seed** → Run workflow ;
   - quand une sauvegarde existe hors du serveur : la ramener dans
     `/srv/backups/restic`, puis `make backup@restore INSTANCE=<instance> SNAPSHOT=<id>`
     (voir [Sauvegardes](sauvegardes.md)).

## 10. Vérifier

```bash
systemctl list-timers 'srv-*' --no-pager   # sauvegarde et nettoyage programmés
systemctl is-active srv-firewall           # active
make -C /srv/server firewall@test          # démo refusée, prod joignable
make -C /srv/server backup@run             # une sauvegarde complète, et le signal Healthchecks.io
docker ps --format '{{.Names}}  {{.Status}}'
```

Et dans un navigateur : https://demo-core.david-grosskost.fr (cadenas, page de connexion),
puis https://mail-demo-core.david-grosskost.fr (mot de passe demandé).
