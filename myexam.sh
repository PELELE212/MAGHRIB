#!/bin/bash
#rajout des depot podman :
sudo nano /etc/containers/registries.conf
#mettre sa 
[registries.search]
registries = ["registry.access.redhat.com", "quay.io"]

[registries.insecure]
registries = ['localhost:5000']
# Création de notre dossier de travaille et copie du fichier index.php dans celui-ci :
sudo mkdir -p /examen/siteweb
sudo cp /vagrant/index.php /examen/siteweb/index.php

#Dans le dossier on créer notre Containerfile :
sudo nano Containerfile
# Et mettre ça dans le container file :
FROM quay.io/jonvangeel/php:7.2-apache

LABEL maintainer="Amine Drz"

RUN docker-php-ext-install mysqli && apachectl restart

ENV DB_HOST=mysql_srv
ENV DB_USER=user1
ENV DB_PASS=azerty
ENV DB_NAME=examen
ENV DB_PORT=3306

COPY index.php /var/www/html/
COPY debug.php /var/www/html/
VOLUME /var/log/apache2

#Modifier le index.php pour qu'il prennent en compte les variable de container file :
#il faut modifier la variable elle est déja présente.
$conn = mysqli_connect(
    getenv("DB_HOST"),
    getenv("DB_USER"),
    getenv("DB_PASS"),
    getenv("DB_NAME"),
    getenv("DB_PORT")
);


# Création des volumes pour persistance
sudo podman volume create mysql_data
sudo podman volume create php_logs ## pas obliger

# Création du réseau personnalisé
sudo podman network create examen-net

# Lancement du conteneur MySQL
sudo podman run -d \
  --name mysql_srv \
  --network examen-net \
  -e MYSQL_ROOT_PASSWORD='rootpass' \
  -e MYSQL_DATABASE='examen' \
  -e MYSQL_USER='user1' \
  -e MYSQL_PASSWORD='azerty' \
  -v mysql_data:/var/lib/mysql \
  quay.io/jonvangeel/mysql-80:latest
#METTRE LES DONNER DANS LA BASE DE DONNER (donner par le prof)
sudo podman exec -it mysql_srv mysql -u user1 -p
#METTRE LES DONNER EN ROOT (donner par le prof)
sudo podman exec -it mysql_srv mysql -u root -p

# Construction de l'image PHP personnalisée
#Aller dans le dossier ou il y'a notre conteneur file et notre index.php :
cd /examen/siteweb
podman build -t siteweb-php .

# Lancement du conteneur PHP
sudo podman run -d \
  --name site_php \
  --network examen-net \
  -p 80:80 \
  -v php_logs:/var/log/php \
  siteweb-php

echo "✅ Déploiement terminé. Accède au site avec http://<IP_VM>"

#Puis faire cette commande pour tester que ça fonctionne :
# apt-install curl
curl http://localhost/
