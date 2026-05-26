{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Helper
  ( testSecret, testExpiry
  , createTestPool, destroyTestPool, runTestMigrations
  , cleanDb
  , mkTestApp
  , makeTestToken
  , registerUser, loginUser
  , findUserIdByEmail
  , promoteUserToAdmin
  , Application
  , methodPost, methodGet, methodPut, methodDelete
  , encodeStrict, simpleBody
  , setTestPool
  , module Test.Hspec
  , module Test.Hspec.Wai
  ) where

import Control.Monad (void)
import Data.Aeson (object, (.=))
import Data.ByteString (ByteString)
import Data.IORef (IORef, newIORef, writeIORef, readIORef)
import Data.Pool (Pool, withResource, destroyAllResources, newPool, defaultPoolConfig, setNumStripes)
import Data.Text (Text)
import Data.Time.Clock (NominalDiffTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple (Connection, Only(..), execute, execute_, query, connectPostgreSQL, close)
import Network.HTTP.Types (methodPost, methodGet, methodPut, methodDelete, StdMethod(..))
import Network.Wai (Application)
import Network.Wai.Test (simpleBody)
import System.Environment (lookupEnv)
import System.IO.Unsafe (unsafePerformIO)

import qualified Data.Aeson as A
import qualified Data.ByteString.Char8 as C
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T

import App (mkApp)
import Auth.JWT (AuthClaims(..), makeToken)
import Config (Env(..))
import Database.Migrations (runMigrations)

import Test.Hspec
import Test.Hspec.Wai hiding (pending, pendingWith)

testSecret :: ByteString
testSecret = "test-secret-key-for-jwt"

testExpiry :: NominalDiffTime
testExpiry = 3600

{-# NOINLINE testPoolRef #-}
testPoolRef :: IORef (Maybe (Pool Connection))
testPoolRef = unsafePerformIO $ newIORef Nothing

setTestPool :: Pool Connection -> IO ()
setTestPool = writeIORef testPoolRef . Just

getTestPool :: IO (Pool Connection)
getTestPool = readIORef testPoolRef >>= \case
  Just pool -> pure pool
  Nothing   -> error "test pool not initialized"

createTestPool :: IO (Pool Connection)
createTestPool = do
  mUrl <- lookupEnv "DATABASE_URL_TEST"
  let url = case mUrl of
        Just u  -> C.pack u
        Nothing -> "postgres://postgres:postgres@localhost:5432/tigrecoin_test"
  newPool $ setNumStripes (Just 1) $ defaultPoolConfig (connectPostgreSQL url) close 10 10

destroyTestPool :: Pool Connection -> IO ()
destroyTestPool = destroyAllResources

runTestMigrations :: Pool Connection -> IO ()
runTestMigrations pool = withResource pool $ \conn ->
  runMigrations conn "migrations"

cleanDb :: IO ()
cleanDb = do
  pool <- getTestPool
  withResource pool $ \conn ->
    void $ execute_ conn "TRUNCATE users, wallets, transactions CASCADE"

mkTestApp :: Pool Connection -> Application
mkTestApp pool = mkApp Env
  { envPool      = pool
  , envJwtSecret = testSecret
  , envJwtExpiry = testExpiry
  }

makeTestToken :: Text -> Text -> IO ByteString
makeTestToken uid role = makeToken testSecret testExpiry (AuthClaims uid role)

encodeStrict :: A.ToJSON a => a -> BL.ByteString
encodeStrict = A.encode

registerUser name email password = void $
  request methodPost "/api/auth/register"
    [("Content-Type", "application/json")]
    (A.encode $ object
      [ "name"     .= name
      , "email"    .= email
      , "password" .= password
      ])

loginUser email password = do
  resp <- request methodPost "/api/auth/login"
    [("Content-Type", "application/json")]
    (A.encode $ object
      [ "email"    .= email
      , "password" .= password
      ])
  pure $ BL.toStrict $ simpleBody resp

findUserIdByEmail :: Text -> IO UUID
findUserIdByEmail email = do
  pool <- getTestPool
  withResource pool $ \conn -> do
    users <- query conn "SELECT id FROM users WHERE email = ?" (Only email)
    case users of
      [Only uid] -> pure uid
      _          -> error $ "User not found: " <> T.unpack email

promoteUserToAdmin :: Text -> IO ()
promoteUserToAdmin email = do
  uid <- findUserIdByEmail email
  pool <- getTestPool
  withResource pool $ \conn ->
    void $ execute conn "UPDATE users SET role = 'admin' WHERE id = ?" (Only uid)
