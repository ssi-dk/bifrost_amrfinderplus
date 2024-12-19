#!/bin/bash
#Script executes these commands with some safeguards in place in case it fails:

if [ -z "$1" ]; then
  echo "Error: No environment name provided."
  echo "Usage: bash $0 <environment_name>"
  exit 1
fi

ENV_NAME=$1
echo "Environment specified $ENV_NAME"

# get directory of current script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR # avoiding small edge case where bashrc sourcing changes your directory

function exit_function() {
  echo "To rerun use the command:"
  echo "bash -i $SCRIPT_DIR/custom_install.sh $ENV_NAME"
  exit 1
}

CONDA_BASE=$(conda info --base)

if [ $? -ne 0 ]; then
  echo "Error: Unable to locate Conda installation."
  exit_function
fi

source $CONDA_BASE/etc/profile.d/conda.sh

# Check if the environment exists
if ! conda env list | grep -q "$ENV_NAME"; then
    echo "Conda environment $ENV_NAME does not exist. Please ensure it is created."
    exit 1
fi


CONDA_ENV_PATH=$(conda env list|awk '{print $2}' | grep -v '^$'|grep "$ENV_NAME")

echo "Activating conda environment"

conda activate $ENV_NAME

AMR_DB_UPDATE_SCRIPT="$CONDA_ENV_PATH/bin/amrfinder_update"
echo "update script $AMR_DB_UPDATE_SCRIPT"

$CONDA_ENV_PATH/bin/amrfinder_update -d $CONDA_ENV_PATH/share/amrfinderplus/data 
echo "$CONDA_ENV_PATH"
echo "$CONDA_ENV_PATH/share/amrfinderplus/data"

#exit_function
#AMR_DB_PATH = "$CONDA_ENV_PATH/share/amrfinderplus/data"
#echo "update script $AMR_DB_PATH"

#checks if file exist and is executable
if [ ! -x "$AMR_DB_UPDATE_SCRIPT" ]; then
  echo "Error: AMR database update script not found at $AMR_DB_UPDATE_SCRIPT."
  exit_function
fi

echo "Updating AMR database with $AMR_DB_UPDATE_SCRIPT"
#$AMR_DB_UPDATE_SCRIPT -d $AMR_DB_PATH 

echo "Updating AMR database is complete"

echo "Installation complete"
