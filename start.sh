#!/usr/bin/bash

if [ ! -f .env ]; then
    echo "ERROR: .env not found! Please copy .env.dist to .env and adjust it to your needs before starting."
    exit 1
fi

. .env

ssh-keygen -f "$HOME.ssh/known_hosts" -R "[localhost]:10022" && rm $HOME.ssh/known_hosts.old

echo "INFO: Starting containers..."
docker-compose up -d

echo "INFO: Waiting for them to be up..."
sleep 15

echo "INFO: Setting domain in Shopware..."
docker-compose exec shopware /usr/bin/mysql -u $SW_USER shopware -e "UPDATE s_core_shops SET host = '$DOMAIN', hosts = '$DOMAIN' WHERE name = 'Dockware';"

echo "INFO: Creating admin user..."
docker-compose exec shopware ./bin/console sw:admin:create --no-interaction --email=$SW_MAIL --username=$SW_USER --name=$SW_USER --password $SW_PASS

echo "INFO: Removing 'demo' user..."
docker-compose exec shopware /usr/bin/mysql -u $SW_USER shopware -e "UPDATE s_core_auth SET active = 0 WHERE username = 'demo'"

echo "INFO: Creating 'English' shop..."
docker-compose exec shopware /usr/bin/mysql -u $SW_USER shopware -e "INSERT INTO s_core_shops VALUES (NULL, '1', 'English', 'English', '0', NULL, NULL, NULL, '', '0', NULL, NULL, '39', '2', '1', '1', '2', '0', '0', '1')"

echo "INFO: Fixing mailer config..."
# See https://github.com/dockware/dockware/issues/34#issuecomment-892564727
docker-compose exec shopware /usr/bin/mysql -u $SW_USER shopware -e "UPDATE s_core_config_elements SET value='s:4:\"smtp\";' WHERE name='mailer_mailer'"
docker-compose exec shopware /usr/bin/mysql -u $SW_USER shopware -e "UPDATE s_core_config_elements SET value='s:4:\"1025\";' WHERE name='mailer_port'"

echo "INFO: Installing Cron plugin..."
docker-compose exec shopware ./bin/console sw:plugin:install Cron
docker-compose exec shopware ./bin/console sw:plugin:activate Cron

# Remark: generated data is pretty useless so far, wait for better version :P
#echo "INFO: Installing sw-cli-tools..."
#sshpass -p$SW_PASS scp -P 10022 bin/sw.phar $SW_USER@localhost:/var/www/html
#sshpass -p$SW_PASS scp -P 10022 bin/sw.phar $SW_USER@localhost:/var/www/.config/sw-cli-tools
#docker-compose exec shopware chmod +x /var/www/html/sw.phar

#echo "INFO: Generating data..."
#docker-compose exec shopware php7.3 sw.phar generate --articles=250 --articleFilterGroups=2 --articleFilterOptions=5 --articleFilterValues=5 --articleMinVariants=1 --articleMaxVariants=5 --categories=25 --categoriesPerArticle=1 --customers=50 --orders 200 -vvv

echo "INFO: Installing SwagImportExport plugin..."
docker-compose exec shopware ./bin/console sw:store:download SwagImportExport
docker-compose exec shopware ./bin/console sw:plugin:install SwagImportExport
docker-compose exec shopware ./bin/console sw:plugin:activate SwagImportExport

if [ -n "$STORE_USER" ]
then
	echo "INFO: Installing ViisonPickwareERP plugin..."
	docker-compose exec shopware ./bin/console sw:store:download --username $STORE_USER --password $STORE_PASS --domain $STORE_DOMAIN ViisonPickwareERP
	docker-compose exec shopware ./bin/console sw:plugin:install ViisonPickwareERP
	docker-compose exec shopware ./bin/console sw:plugin:activate ViisonPickwareERP
	docker-compose exec shopware ./bin/console pickware:erp:stock:init
fi

if [ -f data/sw-domain-hash.html ]; then
    echo "INFO: Installing sw-domain-hash..."
    sshpass -p$SW_PASS scp -o 'StrictHostKeyChecking no' -P 10022 data/sw-domain-hash.html $SW_USER@localhost:/var/www/html
fi

echo "INFO: Installing provided plugins (old plugin system)..."
OLDDIR=$PWD
cd ./data/plugins_old_type/
for type in */ ; do
	cd $type
	for plugin in * ; do
		docker-compose exec shopware ./bin/console sw:plugin:install $plugin
		docker-compose exec shopware ./bin/console sw:plugin:activate $plugin
	done
	cd ..
done
cd $OLDDIR

echo "INFO: Installing provided plugins (new plugin system)..."
OLDDIR=$PWD
cd ./data/plugins_new_type/
for plugin in * ; do
	echo $plugin
	docker-compose exec shopware ./bin/console sw:plugin:install $plugin
	docker-compose exec shopware ./bin/console sw:plugin:activate $plugin
done
cd ..
cd $OLDDIR

echo "INFO: Installing test requirements..."
sshpass -p$SW_PASS scp -o 'StrictHostKeyChecking no' -P 10022 data/add-testing-requirements-v5.7.6.zip $SW_USER@localhost:/var/www/html
docker-compose exec shopware unzip -o add-testing-requirements-v5.7.6.zip

echo "INFO: Clearing Shopware cache..."
docker-compose exec shopware ./bin/console sw:cache:clear

if [ -f data/customers.xml ]; then
    echo "INFO: Importing customers.xml..."
    sshpass -p$SW_PASS scp -P 10022 data/customers.xml $SW_USER@localhost:/var/www/html
    docker-compose exec shopware ./bin/console sw:importexport:import --profile default_customers customers.xml
fi
if [ -f data/addresses.xml ]; then
    echo "INFO: Importing addresses.xml..."
    sshpass -p$SW_PASS scp -P 10022 data/addresses.xml $SW_USER@localhost:/var/www/html
    docker-compose exec shopware ./bin/console sw:importexport:import --profile default_addresses addresses.xml
fi
if [ -f data/sw-test-orders.sql ]; then
    echo "INFO: Importing sw-test-orders.sql..."
    sshpass -p$SW_PASS scp -P 10022 data/sw-test-orders.sql $SW_USER@localhost:/var/www/html
    docker-compose exec shopware /usr/bin/mysql -u $SW_USER shopware -e "source /var/www/html/sw-test-orders.sql"
fi

echo "INFO: Rebuilding search index..."
docker-compose exec shopware ./bin/console sw:refresh:search:index

echo "INFO: Warming cache..."
docker-compose exec shopware ./bin/console sw:warm:http:cache -b 4

