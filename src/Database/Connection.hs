module Database.Connection where

import Data.Pool (Pool, createPool)
import Database.PostgreSQL.Simple (Connection, connectPostgreSQL, close)

import qualified Data.ByteString as BS

createConnectionPool :: BS.ByteString -> IO (Pool Connection)
createConnectionPool connString =
  createPool (connectPostgreSQL connString) close 1 10 10
