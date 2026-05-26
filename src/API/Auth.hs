{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module API.Auth where

import Control.Monad (when)
import Crypto.BCrypt (hashPasswordUsingPolicy, slowerBcryptHashingPolicy, validatePassword)
import Data.Maybe (isJust)
import Data.Pool (withResource)
import Data.Text (Text)
import Data.Time.Clock (getCurrentTime)
import Data.UUID.V4 (nextRandom)
import Servant (ServerT, (:>), (:<|>)(..), Post, ReqBody, JSON, NoContent(..))

import Control.Monad.IO.Class (liftIO)
import Types.AppM (AppM, throwAppError, getPool, getJwtSecret, getJwtExpiry)
import Types.Errors (AppError(..))
import Auth.JWT (AuthClaims(..), makeToken)
import Database.Queries.User qualified as QUser
import Database.Queries.Wallet qualified as QWallet
import Models.User (User(..), UserId(..), RegisterRequest(..), LoginRequest(..))
import Models.Wallet (Wallet(..), WalletId(..))

import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

type AuthAPI =
  "auth" :> (
       "register" :> ReqBody '[JSON] RegisterRequest :> Post '[JSON] NoContent
  :<|> "login"    :> ReqBody '[JSON] LoginRequest    :> Post '[JSON] Text
  )

authServer :: ServerT AuthAPI AppM
authServer = register :<|> login

register :: RegisterRequest -> AppM NoContent
register req = do
  pool <- getPool
  exists <- liftIO $ withResource pool $ \conn ->
    fmap isJust $ QUser.findUserByEmail conn (regEmail req)
  when exists $ throwAppError (Conflict "Email already registered")

  userId <- liftIO nextRandom
  walletId <- liftIO nextRandom
  now <- liftIO getCurrentTime
  passwordHash <- liftIO $ hashPassword (regPassword req)

  let userId'  = UserId userId
      walletId' = WalletId walletId
      user = User
        { userId          = userId'
        , userName        = regName req
        , userEmail       = regEmail req
        , userPasswordHash = passwordHash
        , userRole        = "user"
        , userCreatedAt   = now
        , userUpdatedAt   = now
        }
      wallet = Wallet
        { walletId        = walletId'
        , walletUserId    = userId
        , walletBalance   = 0.0
        , walletCreatedAt = now
        , walletUpdatedAt = now
        }

  liftIO $ withResource pool $ \conn -> do
    QUser.insertUser conn user
    QWallet.insertWallet conn wallet

  pure NoContent

login :: LoginRequest -> AppM Text
login req = do
  pool <- getPool
  secret <- getJwtSecret
  expiry <- getJwtExpiry
  mUser <- liftIO $ withResource pool $ \conn -> QUser.findUserByEmail conn (loginEmail req)
  case mUser of
    Nothing -> throwAppError $ Unauthorized "Invalid email or password"
    Just user -> do
      let valid = validatePassword
            (TE.encodeUtf8 $ userPasswordHash user)
            (TE.encodeUtf8 $ loginPassword req)
      if not valid
        then throwAppError $ Unauthorized "Invalid email or password"
        else do
          let claims = AuthClaims (T.pack $ show $ unUserId $ userId user) (userRole user)
          token <- liftIO $ makeToken secret expiry claims
          pure $ TE.decodeUtf8 token

hashPassword :: Text -> IO Text
hashPassword = fmap (TE.decodeUtf8 . fromJust) . hashPasswordUsingPolicy slowerBcryptHashingPolicy . TE.encodeUtf8
  where
    fromJust (Just x) = x
    fromJust Nothing  = error "bcrypt hashing failed"
