#!/bin/bash

# Check if the required arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 --hdfs <main_hdfs_path> --cutoffdate <YYYYMMDD>"
    exit 1
fi

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --hdfs) HDFS_PATH="$2"; shift ;;
        --cutoffdate) CUTOFF_DATE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Validate cutoff date
if ! [[ $CUTOFF_DATE =~ ^[0-9]{8}$ ]]; then
    echo "Invalid cutoff date format. Expected YYYYMMDD."
    exit 1
fi

# Convert cutoff date to seconds since epoch
CUTOFF_DATE_EPOCH=$(date -d "${CUTOFF_DATE}" +%s)
if [ $? -ne 0 ]; then
    echo "Invalid cutoff date provided."
    exit 1
fi

# Get current timestamp for output files
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Output files
OUTPUT_FILE="hdfs_paths_${TIMESTAMP}.txt"
LOG_FILE="hdfs_paths_${TIMESTAMP}.log"

# Function to recursively traverse HDFS directories
function traverse_hdfs {
    local path="$1"
    local depth="$2"
    
    echo "Checking path: $path" >> "$LOG_FILE"
    
    # List directories and files at the current path
    hdfs dfs -ls "$path" | while read -r line; do
        # Extract type, modification time, and file path
        local type=$(echo "$line" | awk '{print $1}')
        local mod_time=$(echo "$line" | awk '{print $6, $7}')
        local file_path=$(echo "$line" | awk '{print $8}')
        
        if [[ "$type" == "d" ]]; then
            # Recursively traverse directories
            traverse_hdfs "$file_path" $((depth + 1))
        else
            # Check if file modification time is older than the cutoff date
            local file_epoch=$(date -d "$mod_time" +%s)
            if [ "$file_epoch" -lt "$CUTOFF_DATE_EPOCH" ]; then
                echo "$file_path" >> "$OUTPUT_FILE"
                echo -e "\e[31m$file_path (Depth: $depth) - Older than cutoff date\e[0m" >> "$LOG_FILE"
            else
                echo -e "\e[32m$file_path (Depth: $depth) - Newer than cutoff date\e[0m" >> "$LOG_FILE"
            fi
        fi
    done
}

# Start the recursive traversal
traverse_hdfs "$HDFS_PATH" 0

echo "Execution completed. Paths older than the cutoff date are listed in $OUTPUT_FILE."
echo "Detailed log is available in $LOG_FILE."
