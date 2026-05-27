module Database.Connection (createConnectionPool) where

import Data.Pool (Pool, newPool, defaultPoolConfig, setNumStripes)
import Database.PostgreSQL.Simple (Connection, connectPostgreSQL, close)

import qualified Data.ByteString as BS

createConnectionPool :: BS.ByteString -> IO (Pool Connection)
createConnectionPool connString =
  -- createPool (connectPostgreSQL connString) close 1 10 10
  newPool $ setNumStripes (Just 1) $ defaultPoolConfig (connectPostgreSQL connString) close 10 10