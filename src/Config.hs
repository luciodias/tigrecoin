module Config where

import Data.ByteString (ByteString)
import Data.Pool (Pool)
import Data.Time.Clock (NominalDiffTime)
import Database.PostgreSQL.Simple (Connection)

data Env = Env
  { envPool      :: Pool Connection
  , envJwtSecret :: ByteString
  , envJwtExpiry :: NominalDiffTime
  }
