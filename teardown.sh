#!/bin/bash
#set -e

docker-compose -f docker-compose.yml down
 
# Shut down the Docker containers for the system tests.
docker-compose -f docker-compose.yml kill && docker-compose -f docker-compose.yml down

# remove the local state
rm -f ~/.hfc-key-store/*

# remove configs
rm -fr config/*
rm -fr crypto-config/*
rm -fr idemix-config/*
rm -ft certs/*
rm -fr testcert/*
rm -fr testcerts/*

# remove chaincode docker images
docker rm $(docker ps -aq)

# remove all
docker-compose -f docker-compose.yml down -v

# Your system is now clean