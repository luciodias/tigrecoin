{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module API.User where

import Control.Monad.IO.Class (liftIO)
import Data.Pool (withResource)
import Data.Text (Text)
import Data.UUID (UUID)
import Servant (ServerT, (:>), (:<|>)(..), Get, Put, Delete, ReqBody, JSON, Capture, NoContent(..))

import Types.AppM (AppM, throwAppError, getPool)
import Types.Errors (AppError(..))
import Auth.Middleware (AuthUser(..))
import Database.Queries.User qualified as QUser
import Models.User (User(..), UserId(..), UpdateUserRequest(..), toUserResponse, UserResponse)

type UserAPI =
  "users" :> Capture "id" UUID :> (
       Get    '[JSON] UserResponse
  :<|> ReqBody '[JSON] UpdateUserRequest :> Put '[JSON] UserResponse
  :<|> Delete '[JSON] NoContent
  )

userServer authUser uuid =
     getUser authUser uuid
 :<|> updateUser authUser uuid
 :<|> deleteUser authUser uuid

getUser :: AuthUser -> UUID -> AppM UserResponse
getUser _ uid = do
  pool <- getPool
  mUser <- liftIO $ withResource pool $ \conn -> QUser.findUserById conn uid
  case mUser of
    Nothing -> throwAppError $ NotFound "User not found"
    Just user -> pure $ toUserResponse user

updateUser :: AuthUser -> UUID -> UpdateUserRequest -> AppM UserResponse
updateUser _ uid req = do
  pool <- getPool
  liftIO $ withResource pool $ \conn -> QUser.updateUser conn uid (updName req) (updEmail req)
  mUser <- liftIO $ withResource pool $ \conn -> QUser.findUserById conn uid
  case mUser of
    Nothing -> throwAppError $ NotFound "User not found"
    Just user -> pure $ toUserResponse user

deleteUser :: AuthUser -> UUID -> AppM NoContent
deleteUser authUser uid = do
  if auRole authUser /= "admin"
    then throwAppError $ Forbidden "Only admins can delete users"
    else do
      pool <- getPool
      liftIO $ withResource pool $ \conn -> QUser.deleteUser conn uid
      pure NoContent
