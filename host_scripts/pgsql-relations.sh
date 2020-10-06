#!/bin/bash
set -ex
# Source the helper functions
. functions.sh
# Initialize the log file
logfile_created=false

lucky set-status -n db-relation-status maintenance \
  "Configuring PostgreSQL relation"

# Capture count of pgsql relations
rel_count=$(lucky relation list-ids -n db | wc -l)
log_this "Relation count: ${rel_count}"

# Do different stuff based on which hook is running
if [ &{LUCKY_HOOK} == "db-relation-joined" ]; then
  if [ ${rel_count} -eq 1 ]; then
    log_this "Relation data $(lucky relation get --app)"
    # Set the data
    set_pgsql_kv_data
    # Log it
    log_this "KV data after setting: $(lucky kv get)"
  elif [ ${rel_count} -gt 1 ]; then
    lucky set-status -n db-relation-status blocked \
      "One and only one relation to PostgreSQL required; remove relation ${JUJU_RELATION}"
    exit 0
  fi
elif [ ${LUCKY_HOOK} == "db-relation-changed" ]; then 
  # Log the relation data before
  log_this "Relation data: $(lucky relation get --app)"
  # Set the data
  set_pgsql_kv_data
  # Log the relation data after
  log_this "KV data after setting: $(lucky kv get)"
  # Run the update script without forking
  exec ./host_scripts/update-config.sh
elif [ ${LUCKY_HOOK} == "db-relation-departed" ]; then
  if [ ${rel_count} -eq 0 ]; then
    log_this "Removing the following pgsql KV data"
    delete_pgsql_kv_data
    lucky set-status -n db-relation-status blocked \
      "One and only one relation to PostgreSQL required"
    exit 0
  fi
  # Run the update script
  exec ./host_scripts/update-config.sh
elif [ ${LUCKY_HOOK} == "db-relation-broken" ]; then
  # In this context, the departing relation is still included in the output
  # Therefore we reduce by 1
  new_count=$((${rel_count} - 1))
  if [ ${new_count} -eq 0 ]; then
    log_this "Removing the following KV data: $(lucky kv get)"
    delete_pgsql_kv_data
    lucky set-status -n db-relation-status blocked \
      "One and only one relation to PostgreSQL required; remove relation ${JUJU_RELATION}"
    exit 0
  fi
fi

lucky set-status -n db-relation-status active