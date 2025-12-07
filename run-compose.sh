#!/bin/bash

# Define color and formatting codes
BOLD='\033[1m'
GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m' # No Color
# Unicode character for tick mark
TICK='\u2713'

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --webui[port=PORT]         Set the port for the web user interface (default: 3000)."
    echo "  --playwright               Enable Playwright support for web scraping."
    echo "  --build                    Build the docker image before running the compose project."
    echo "  --drop                     Drop the compose project."
    echo "  -q, --quiet                Run script in headless mode."
    echo "  -h, --help                 Show this help message."
    echo ""
    echo "Examples:"
    echo "  $0 --drop"
    echo "  $0 --webui[port=3000]"
    echo "  $0 --webui[port=3000] --build"
    echo "  $0 --webui[port=3000] --playwright --build"
    echo ""
    echo "This script configures and runs a docker-compose setup for Open WebUI."
}

# Default values
webui_port=3000
headless=false
build_image=false
kill_compose=false
enable_playwright=false

# Function to extract value from the parameter
extract_value() {
    echo "$1" | sed -E 's/.*\[.*=(.*)\].*/\1/; t; s/.*//'
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --webui*)
            value=$(extract_value "$key")
            webui_port=${value:-3000}
            ;;
        --playwright)
            enable_playwright=true
            ;;
        --drop)
            kill_compose=true
            ;;
        --build)
            build_image=true
            ;;
        -q|--quiet)
            headless=true
            ;;
        -h|--help)
            usage
            exit
            ;;
        *)
            # Unknown option
            echo "Unknown option: $key"
            usage
            exit 1
            ;;
    esac
    shift # past argument or value
done

if [[ $kill_compose == true ]]; then
    docker compose down --remove-orphans
    echo -e "${GREEN}${BOLD}Compose project dropped successfully.${NC}"
    exit
else
    DEFAULT_COMPOSE_COMMAND="docker compose -f docker-compose.yaml"
    
    if [[ $enable_playwright == true ]]; then
        DEFAULT_COMPOSE_COMMAND+=" -f docker-compose.playwright.yaml"
    fi
    if [[ -n $webui_port ]]; then
        export OPEN_WEBUI_PORT=$webui_port # Set OPEN_WEBUI_PORT environment variable
    fi
    DEFAULT_COMPOSE_COMMAND+=" up -d"
    DEFAULT_COMPOSE_COMMAND+=" --remove-orphans"
    DEFAULT_COMPOSE_COMMAND+=" --force-recreate"
    DEFAULT_COMPOSE_COMMAND+=" --pull never"
    if [[ $build_image == true ]]; then
        DEFAULT_COMPOSE_COMMAND+=" --build"
    fi
fi

# Recap of environment variables
echo
echo -e "${WHITE}${BOLD}Current Setup:${NC}"
echo -e "   ${GREEN}${BOLD}WebUI Port:${NC} $webui_port"
echo -e "   ${GREEN}${BOLD}Playwright:${NC} ${enable_playwright:-false}"
echo

if [[ $headless == true ]]; then
    echo -ne "${WHITE}${BOLD}Running in headless mode... ${NC}"
    choice="y"
else
    # Ask for user acceptance
    echo -ne "${WHITE}${BOLD}Do you want to proceed with current setup? (Y/n): ${NC}"
    read -n1 -s choice
fi

echo

if [[ $choice == "" || $choice == "y" ]]; then
    # Execute the command with the current user
    eval "$DEFAULT_COMPOSE_COMMAND" &

    # Capture the background process PID
    PID=$!

    # Wait for the command to finish
    wait $PID

    echo
    # Check exit status
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${BOLD}Compose project started successfully.${NC}"
    else
        echo -e "${RED}${BOLD}There was an error starting the compose project.${NC}"
    fi
else
    echo "Aborted."
fi

echo
