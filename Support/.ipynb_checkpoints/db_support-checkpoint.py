# Import the needed libraries

import pandas as pd
import sqlalchemy as sa
import os
from dotenv import load_dotenv

# Get the DB URL from environment file in order execute you must have the .env file in your root folder with URL string
load_dotenv()  # This loads the .env file
DATABASE_URL = os.getenv('DATABASE_URL')

# creating connections
engine = sa.create_engine(DATABASE_URL)
connection = engine.connect().execution_options(isolation_level="AUTOCOMMIT")

def execute_sql_file(sql_file_path):
    """
    Execute a SQL file  and returns the resuls as pandas Dataframe.

    :param sql_file_path: path to the SQL file.
    :param db_connections: A Connections object to the database
    """
       
    #Read the SQL file
    with open(sql_file_path, 'r') as file:
        sql_query = file.read()

    #Execute the query and fetcht the result in to dataframe
    df = pd.read_sql_query(sql_query, connection)

    return df

def check_tables():
    """
    Checks and returns the list of table names in the database.

    :param engine: SQLAlchemy engine object.
    :return: List of table names.
    """
    inspector = sa.inspect(engine)
    return inspector.get_table_names()


def table_row_count():
    table_counts = {}
    inspector = sa.inspect(engine)
    # Loop throught the table names ange get the count
    for table in inspector.get_table_names():
        query = f"SELECT COUNT(*) FROM {table}"
        result = pd.read_sql_query(query, connection)
        table_counts[table] = result.iloc[0, 0]  # Get the count from the first (and only) row

    # Print the count of records
    for table, count in table_counts.items():
        print(f"{table}: {count} records")



