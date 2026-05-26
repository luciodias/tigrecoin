{-# LANGUAGE OverloadedStrings #-}

module Database.Queries.User where

import Control.Monad (void)
import Data.Pool (withResource)
import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple (Connection, Only(..), query, query_, execute, execute_)

import Models.User (User(..), UserId(..))

findUserByEmail :: Connection -> Text -> IO (Maybe User)
findUserByEmail conn email = do
  users <- query conn
    "SELECT id, name, email, password_hash, role, created_at, updated_at FROM users WHERE email = ?"
    (Only email)
  pure $ case users of
    (u:_) -> Just u
    []    -> Nothing

findUserById :: Connection -> UUID -> IO (Maybe User)
findUserById conn uid = do
  users <- query conn
    "SELECT id, name, email, password_hash, role, created_at, updated_at FROM users WHERE id = ?"
    (Only uid)
  pure $ case users of
    (u:_) -> Just u
    []    -> Nothing

insertUser :: Connection -> User -> IO ()
insertUser conn user = void $ execute conn
  "INSERT INTO users (id, name, email, password_hash, role) VALUES (?, ?, ?, ?, ?)"
  (userId user, userName user, userEmail user, userPasswordHash user, userRole user)

updateUser :: Connection -> UUID -> Text -> Text -> IO ()
updateUser conn uid name email = void $ execute conn
  "UPDATE users SET name = ?, email = ?, updated_at = NOW() WHERE id = ?"
  (name, email, uid)

deleteUser :: Connection -> UUID -> IO ()
deleteUser conn uid = void $ execute conn
  "DELETE FROM users WHERE id = ?"
  (Only uid)
