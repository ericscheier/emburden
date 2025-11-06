#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Jun 27 13:51:27 2024

@author: ess
"""

import json
import sqlite3
import os
import re
import time

def get_all_keys(data):
    """Recursively get all keys in the JSON structure."""
    keys = set()
    if isinstance(data, dict):
        for key, value in data.items():
            keys.add(key)
            if isinstance(value, dict):
                keys.update(get_all_keys(value))
            elif isinstance(value, list):
                for item in value:
                    keys.update(get_all_keys(item))
    elif isinstance(data, list):
        for item in data:
            keys.update(get_all_keys(item))
    return keys

def sanitize_key(key):
    """Sanitize the key to be a valid SQLite identifier."""
    return re.sub(r'\W|^(?=\d)', '_', key).lower()

def convert_to_str(data):
    """Convert all values in the dictionary to strings."""
    for key in data:
        if isinstance(data[key], (dict, list)):
            data[key] = json.dumps(data[key])
        else:
            data[key] = str(data[key])
    return data

def add_missing_columns(cursor, table_name, data_keys):
    """Add any missing columns to the table."""
    cursor.execute(f"PRAGMA table_info({table_name})")
    existing_columns = set(row[1].lower() for row in cursor.fetchall())
    for key in data_keys:
        sanitized_key = sanitize_key(key)
        if sanitized_key not in existing_columns:
            cursor.execute(f"ALTER TABLE {table_name} ADD COLUMN {sanitized_key} TEXT")

# Function to create a table dynamically based on JSON structure
def create_table(cursor, table_name, keys):
    fields = []
    for key in keys:
        sanitized_key = sanitize_key(key)
        fields.append(f"{sanitized_key} TEXT")
    fields_str = ", ".join(fields)
    cursor.execute(f"CREATE TABLE IF NOT EXISTS {table_name} (id INTEGER PRIMARY KEY, {fields_str})")

# Function to insert data into table with retry mechanism
def insert_data(cursor, table_name, data, retries=5, delay=1):
    data = convert_to_str(data)  # Convert all values to strings
    sanitized_data = {sanitize_key(k): v for k, v in data.items()}
    add_missing_columns(cursor, table_name, sanitized_data.keys())
    columns = ', '.join(sanitized_data.keys())
    placeholders = ', '.join(['?' for _ in sanitized_data])
    sql = f"INSERT INTO {table_name} ({columns}) VALUES ({placeholders})"
    
    for attempt in range(retries):
        try:
            cursor.execute(sql, tuple(sanitized_data.values()))
            break
        except sqlite3.OperationalError as e:
            if 'database is locked' in str(e) and attempt < retries - 1:
                time.sleep(delay)
            else:
                raise

def connect_with_retry(db_path, retries=5, delay=1):
    """Retry connecting to the database if it is locked."""
    for attempt in range(retries):
        try:
            conn = sqlite3.connect(db_path)
            return conn
        except sqlite3.OperationalError as e:
            if 'database is locked' in str(e) and attempt < retries - 1:
                time.sleep(delay)
            else:
                raise

# Load JSON data
file_path = 'data/usurdb.json'
with open(file_path) as f:
    data = json.load(f)

# Connect to SQLite database with retry mechanism
db_path = 'data/usurdb.db'
conn = connect_with_retry(db_path)
c = conn.cursor()

# Determine the table name from file name
table_name = os.path.splitext(os.path.basename(file_path))[0]

# Get all keys from the JSON data
if isinstance(data, list):
    all_keys = set()
    for item in data:
        all_keys.update(get_all_keys(item))
else:
    all_keys = get_all_keys(data)

# Create table with all possible keys
create_table(c, table_name, all_keys)

# Insert data into the table
if isinstance(data, list):
    for item in data:
        insert_data(c, table_name, item)
else:
    insert_data(c, table_name, data)

# Commit the transaction and close the connection
conn.commit()
conn.close()
