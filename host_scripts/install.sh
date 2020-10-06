#!/bin/bash
# Exit non-zero is any command in the script exits non-zero
set -e

# Say that we are in the middle of installing
lucky set-status maintenance 'Installing Drupal'

# Create a Docker container by setting the container image to use
lucky container image set drupal:8.8.6-apache

# Indicate we are done installing
lucky set-status active
