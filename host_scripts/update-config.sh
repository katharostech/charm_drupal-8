#!/bin/bash
set -e
# Source the helper functions
. functions.sh
# Initialize the log file
logfile_created=false

# Put in maintenance mode
lucky set-status -n config-status  maintenance "Config changed; reconfiguring Drupal"

# Exit and block if the relation with the DB is not setup
if [ $(lucky relation list-ids -n db | wc -l) -ne 1 ]; then
  # Set config status back to active
  lucky set-status -n config-status active
  # Set relation status to blocked and exit
  lucky set-status -n db-relation-status blocked \
    "One and only one relation to RethinkDB required"
  exit 0
else
  lucky set-status -n db-relation-status active
fi

# Verify all config setting requirements met
sc_config_check

# Remove previously opened ports
lucky port close --all
lucky container port remove --all

# Bind the Drupal port
set_container_port
lucky container port add $(lucky kv get bind_port):80
lucky port open $(lucky kv get bind_port)

lucky set-status -n config-status active
