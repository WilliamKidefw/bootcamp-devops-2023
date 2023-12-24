#!/bin/bash

BRED='\033[1;31m'       # Bold Red
BGREEN='\033[1;32m'     # Bold Green
BYELLOW='\033[1;33m'    # Bold Yellow
UCYAN='\033[4;36m'      # Underline Cyan
LGREY='\033[0;90m'      # Dark Gray
TR='\033[0m'            # Text Reset

#Global Variables
WEB_URL="localhost"
DISCORD_KEY="https://discord.com/api/webhooks/1154865920741752872/au1jkQ7v9LgQJ131qFnFqP-WWehD40poZJXRGEYUDErXHLQJ_BBszUFtVj8g3pu9bm7h"

#stage 1: install
function stage1() {
    echo -e "${UCYAN}STAGE1${TR}"
	echo "==================================================================================="
	echo "Monolith LAMP application deployment automation script"
	echo "This version is for Debian based distro"
	echo "==================================================================================="

	#check if the current user is root or uses sudo command
	if [ "$(id -nu)" != "root" ]; then
		echo -e "${BRED}Your account does not have enough administrative privileges${TR}"
		exit 1
	fi
	
	echo -e "${BYELLOW}Please wait while checking status of the needed packages${TR}"

	declare -a package_installed
	declare -a package_not_installed

	install_packages() {
		local packages=("${@}")
		apt install "${packages[@]}" -y
	}

	check_installation() {
		local command_name=$1
		local packages=("${@:2}")

		if hash "$command_name" 2>/dev/null; then
			package_installed+=("$command_name")
		else
			package_not_installed+=("${packages[@]}")
		fi
	}

	check_installation "php" "php-mysql" "php-mbstring" "php-zip" "php-gd" "php-json" "php-curl"
	check_installation "mariadb" "mariadb-server"
	check_installation "apache2" "libapache2-mod-php"
	check_installation "git"
	check_installation "curl"

	if [ ${#package_installed[@]} -gt 0 ]; then
		echo -e "${BYELLOW}Number of installed packages : ${#package_installed[@]}${TR}"
    	echo -e "${BYELLOW}Installed packages: ${package_installed[@]}${TR}"
	else
		echo -e "${BGREEN}It requires a complete installation${TR}"
	fi

	if [ ${#package_not_installed[@]} -gt 0 ]; then
		echo -e "${BYELLOW}Number of packages not installed: ${#package_not_installed[@]}${TR}"
		echo -e "${BYELLOW}The next packages will be installed: ${package_not_installed[@]}${TR}"
		# Update system and install missing packages
		echo -e "${BYELLOW}Updating system${TR}"
		apt update
		install_packages "${package_not_installed[@]}"
		echo -e "${BGREEN}Package installation done${TR}"
	else
		echo -e "${BGREEN}All packages are installed${TR}"
	fi
	sleep 1
}

#stage: check
function health_check() {
    echo -e "${UCYAN}HEALTH CHECK${TR}"

	declare -a packages_up
	declare -a packages_down

	check_service_status() {
		local service_name=$1

		if systemctl is-active --quiet "$service_name"; then
			packages_up+=("$service_name")
		else
			packages_down+=("$service_name")
		fi
	}

	check_command_existence() {
		local command_name=$1

		if command -v "$command_name" > /dev/null 2>&1; then
			packages_up+=("$command_name")
		else
			packages_down+=("$command_name")
		fi
	}

	# Check service statuses
	check_service_status "mariadb"
	check_service_status "apache2"

	# Check command existence
	check_command_existence "php"
	check_command_existence "git"
	check_command_existence "curl"

	# Display packages up and running
	echo -e "${BGREEN}Packages up and running: ${TR}"
	for package in "${packages_up[@]}"; do
		echo "$package"
	done

	# Display packages with error status and exit if any
	if [ ${#packages_down[@]} -gt 0 ]; then
		echo -e "${BGREEN}Packages with error status:${TR}"
		for package in "${packages_down[@]}"; do
			echo "$package"
		done
		exit 1
	fi

	echo -e "${BGREEN}All packages are set and ready for the next stage${TR}"
}

#stage 2: build
function stage2() {
	echo -e "${UCYAN}STAGE2${TR}"
	
	datalayer_flag=0
    WEBAPPDB="devopstravel"
	ROOT_PROJECT="desafio01"
    SOURCODE="https://github.com/WilliamKidefw/bootcamp-devops-2023.git"
    APP_REPO="app-295devops-travel"
    GIT_BRANCH="clase2-linux-bash"

	#filepath: this is very important for redhat based distros
	filepath="/etc/apache2/mods-enabled/dir.conf"
	#I should check if the file exists
	
	#backup of the original file
	cp "$filepath" "$filepath.bk"
	
	#read the file
	dirfile=$(cat "$filepath")
	
	#adding index.php
	newdirfile=$(sed -r 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/' <<< "$dirfile")
	
	#writing changes
	echo "$newdirfile" > "$filepath"
        echo -e "${BYELLOW}Restarting web server...${TR}"
	systemctl restart apache2
	#it should be a call to health_check() to evaluate if Apache is running after this change
	sleep 3
	
	echo "Checking if the database layer is already set up"
	
	mysql -u root -e "SHOW DATABASES LIKE '$WEBAPPDB';" | grep "$WEBAPPDB" > /dev/null

	if [[ $? -eq 0 ]]; then
		echo -e "${BGREEN}The database '$WEBAPPDB' exists, the data layer is ready${TR}"
		datalayer_flag="1"
	else
		echo -e "${BYELLOW}Configuring data layer access...${TR}"
		mysql < ./script-config-db.sql
	fi
	
	sleep 1

	echo -e "${BYELLOW}Connecting to the codebase...${TR}"

	if [ -d $ROOT_PROJECT ]; then
		echo -e "${BGREEN}Application exists, searching for updates...${TR}"
		sleep 1
		cd $ROOT_PROJECT
		git pull origin $GIT_BRANCH
	else
		echo -e "${BYELLOW}Clone repository...${TR}"
		git clone $SOURCODE $ROOT_PROJECT
		cd $ROOT_PROJECT
	fi
	
	#moving to the source code

	git checkout $GIT_BRANCH

	echo -e "${BYELLOW}Updating DB credentials in the WebApp config...${TR}"
	sed -i 's/$dbPassword = ""/$dbPassword = "codepass"/g' $APP_REPO/config.php
	#please check if after this mod config.php has root permissions
	
	if [[ $datalayer_flag -eq 0 ]]; then
		echo -e "${BYELLOW}Seeding data...${TR}"
		mysql < $APP_REPO/database/devopstravel.sql
	fi
	sleep 3	
	
	echo -e "${BYELLOW}Installing App into the Web Server ...${TR}"
	cp -r $APP_REPO/ /var/www/html/$ROOT_PROJECT
	sleep 2

    cd ..

	echo -e "${BYELLOW}Checking if the environment and the WebApp are ready...${TR}"
	enviro_status=$(php /var/www/html/$ROOT_PROJECT/info.php)

	if [[ $enviro_status=~"Loaded Configuration File" && $enviro_status=~"PHP Version" ]]; then
		echo -e "${BGREEN}The code base is installed, up and running${TR}"
	else
		echo -e "${BYELLOW}The environment is not ready, please contact to IT support${TR}"
		exit 1
	fi
}

#stage 3: deploy
function stage3() {
    echo -e "${UCYAN}STAGE3${TR}"
	systemctl reload apache2
	sleep 1
	app_status=$(curl -s -o /dev/null -w "%{http_code}" http://$WEB_URL/$ROOT_PROJECT/index.php)

	if [ $app_status -eq 200 ]; then
		echo -e "${BGREEN}The application is fully functional${TR}"
        return 1
	else
		echo -e "${BYELLOW}Unfortunately the application is not ready to enter into production. Please notify to production${TR}"
		return 0
	fi
}

#stage 4: notify
function stage4() {
    echo -e "${UCYAN}STAGE4${TR}"
    status_app=$1

    REPO_NAME=$(basename $(git rev-parse --show-toplevel))
    REPO_URL=$(git remote get-url origin)

    DEPLOYMENT_INFO2="Despliegue del repositorio $REPO_NAME: "
    COMMIT="Commit: $(git rev-parse --short HEAD)"
    AUTHOR="Autor: $(git log -1 --pretty=format:'%an')"
    DESCRIPTION="Descripción: $(git log -1 --pretty=format:'%s')"
    MAINTAINER="Maintainer: GROUP_5"
    if [ $status_app -eq 1 ]; then
        DEPLOYMENT_INFO="Challenge 01 Web Application deploy using Bash Scripting \nPlease refer to the README.md"
    else
        DEPLOYMENT_INFO="La página web $WEB_URL no está en línea."
    fi

    MESSAGE="$DEPLOYMENT_INFO\n$DEPLOYMENT_INFO2\n$COMMIT\n$AUTHOR\n$DESCRIPTION\n$REPO_URL\n$MAINTAINER"
    
    curl -X POST -H "Content-Type: application/json" \
     -d '{
       "content": "'"${MESSAGE}"'"
     }' "$DISCORD_KEY"
}


main() {
	stage1
	health_check

	sleep 1
	#it is important to check if the app is running before running the stage2	
	echo -e "${LGREY}Installing code base...${TR}"
	stage2
	
	sleep 3

	echo -e "${LGREY}Deploying to production...${TR}"

	stage3
    stage3_result=$?

	sleep 1

	echo -e "${LGREY}Sending message to discord...${TR}"
	stage4 $stage3_result
}

main
