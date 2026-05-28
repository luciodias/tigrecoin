module Types.AppM where

import Control.Monad.Except (throwError)
import Control.Monad.Reader (ReaderT, asks)
import Control.Monad.Reader (lift)
import Data.ByteString (ByteString)
import Data.Pool (Pool)
import Data.Time.Clock (NominalDiffTime)
import Database.PostgreSQL.Simple (Connection)
import Servant (Handler, ServerError)

import Config (Env(..))
import Types.Errors (AppError, appErrorToServerError)

type AppM = ReaderT Env Handler

throwServerError :: ServerError -> AppM a
throwServerError = lift . throwError

throwAppError :: AppError -> AppM a
throwAppError = throwServerError . appErrorToServerError

getPool :: AppM (Pool Connection)
getPool = asks envPool

getJwtSecret :: AppM ByteString
getJwtSecret = asks envJwtSecret

getJwtExpiry :: AppM NominalDiffTime
getJwtExpiry = asks envJwtExpiry
