{-# LANGUAGE OverloadedStrings #-}

module Models.User where

import Data.Aeson (FromJSON, ToJSON, (.=), (.:), object, parseJSON, withObject)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromField (FromField(..))
import Database.PostgreSQL.Simple.FromRow (FromRow, field)
import Database.PostgreSQL.Simple.ToField (ToField(..))

import qualified Data.UUID as UUID

newtype UserId = UserId { unUserId :: UUID }

instance FromField UserId where
  fromField f mbs = UserId <$> fromField f mbs

instance ToField UserId where
  toField = toField . unUserId

data User = User
  { userId          :: !UserId
  , userName        :: !Text
  , userEmail       :: !Text
  , userPasswordHash :: !Text
  , userRole        :: !Text
  , userCreatedAt   :: !UTCTime
  , userUpdatedAt   :: !UTCTime
  }

instance FromRow User where
  fromRow = User <$> field <*> field <*> field <*> field <*> field <*> field <*> field

data RegisterRequest = RegisterRequest
  { regName     :: !Text
  , regEmail    :: !Text
  , regPassword :: !Text
  }

instance FromJSON RegisterRequest where
  parseJSON = withObject "RegisterRequest" $ \o ->
    RegisterRequest
      <$> o .: "name"
      <*> o .: "email"
      <*> o .: "password"

data LoginRequest = LoginRequest
  { loginEmail    :: !Text
  , loginPassword :: !Text
  }

instance FromJSON LoginRequest where
  parseJSON = withObject "LoginRequest" $ \o ->
    LoginRequest
      <$> o .: "email"
      <*> o .: "password"

data UpdateUserRequest = UpdateUserRequest
  { updName  :: !Text
  , updEmail :: !Text
  }

instance FromJSON UpdateUserRequest where
  parseJSON = withObject "UpdateUserRequest" $ \o ->
    UpdateUserRequest
      <$> o .: "name"
      <*> o .: "email"

data UserResponse = UserResponse
  { urespId        :: !UUID
  , urespName      :: !Text
  , urespEmail     :: !Text
  , urespRole      :: !Text
  , urespCreatedAt :: !UTCTime
  }

instance ToJSON UserResponse where
  toJSON u = object
    [ "id"         .= urespId u
    , "name"       .= urespName u
    , "email"      .= urespEmail u
    , "role"       .= urespRole u
    , "created_at" .= urespCreatedAt u
    ]

toUserResponse :: User -> UserResponse
toUserResponse u = UserResponse
  (unUserId $ userId u)
  (userName u)
  (userEmail u)
  (userRole u)
  (userCreatedAt u)
