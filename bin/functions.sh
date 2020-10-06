#!/bin/bash
set -ex

# function to send log messages to a file
log_this () {

  # create the logfile if needed
  if [ !${logfile_created} ]; then
    # gather some data
    now=$(date "+%Y%m%d-%H%M%S")
    logdir=/var/log/lucky
    script="${0}"
    scriptbase=$(basename -s ".sh" "${script}")
    logname="${scriptbase}"
    logfile="${logdir}/${logname}-${now}.log"

    # create the dir if it doesn't exist
    mkdir -p ${logdir}
    touch ${logfile}
    # say we created it
    logfile_created=true
  fi

  # write message to log
  echo "${LUCKY_HOOK}::${1}" >> ${logfile}

  # clean up files older than 10 minutes
  find ${logdir} -name "${logname}-*" -mmin +10 -print | xargs rm -f
}

# Function to set the http interface relation
# Convention found here: https://discourse.jujucharms.com/t/interface-http/2392
set_http_relation () {
  # Set port if needed
  set_container_port
  
  # Get the port from the KV store
  bind_port=$(lucky kv get bind_port)

  # Log it
  log_this "hostname: $(lucky private-address)"
  log_this "port: ${bind_port}"

  # Publish the listen address to the relation
  lucky relation set "hostname=$(lucky private-address)"
  lucky relation set "port=${bind_port}"
}

# function to remove the listen_address
remove_http_relation () {
  log_this \
    "Removing relation value for 'hostname': $(lucky relation get hostname)"
  lucky relation set hostname=""
  log_this \
    "Removing relation value for 'port': $(lucky relation get port)"
  lucky relation set port=""
  log_this "hostname and port relation values removed"
}

set_container_port () {
  # Get random port if not set
  if [ -z "$(lucky kv get bind_port)" ]; then
    # Use random function of Lucky
    rand_port=$(lucky random --available-port)
    lucky kv set bind_port="$rand_port"
  fi
}

set_pgsql_kv_data () {
  # Set values required by PostgreSQL Charm
  lucky relation set "database=$(lucky get-config db-name)"
  # Set the KV values based on reql relation data
  lucky kv set "pgsql_host=$(lucky relation get --app host)"
  lucky kv set "pgsql_port=$(lucky relation get --app port)"
  lucky kv set "pgsql_user=$(lucky relation get --app user)"
  lucky kv set "pgsql_password=$(lucky relation get --app password)"
  lucky kv set "pgsql_schema_user=$(lucky relation get --app schema_user)"
  lucky kv set "pgsql_schema_password=$(lucky relation get --app schema_password)"
  lucky kv set "pgsql_state=$(lucky relation get --app state)"
  lucky kv set "pgsql_version=$(lucky relation get --app version)"
}

delete_pgsql_kv_data () {
  # Remove values required by PostgreSQL Charm
  lucky relation set database=""
  # Delete the KV values
  lucky kv delete "pgsql_host"
  lucky kv delete "pgsql_port"
  lucky kv delete "pgsql_user"
  lucky kv delete "pgsql_password"
  lucky kv delete "pgsql_schema_user"
  lucky kv delete "pgsql_schema_password"
  lucky kv delete "pgsql_state"
  lucky kv delete "pgsql_version"
}

sc_config_check () {
  # Get config values
  db_name=$(lucky get-config db-name)
  
  # Check global configs
  if [ -z ${db_name} ]; then
    lucky set-status -n config-status blocked \
    "Config required: 'db-name'"
    exit 0
  # elif [ -z ${server_proto} ]; then
  #   lucky set-status -n config-status blocked \
  #   "Config required: 'server-proto'"
  #   exit 0
  fi
}
