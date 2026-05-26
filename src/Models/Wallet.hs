{-# LANGUAGE OverloadedStrings #-}

module Models.Wallet where

import Data.Aeson (FromJSON, ToJSON, (.=), object, parseJSON, withObject, (.:))
import Data.ByteString (ByteString)
import Data.Time.Clock (UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromField (FromField(..))
import Database.PostgreSQL.Simple.FromRow (FromRow, field)
import Database.PostgreSQL.Simple.ToField (ToField(..))

import qualified Data.UUID as UUID

newtype WalletId = WalletId { unWalletId :: UUID }

instance FromField WalletId where
  fromField f mbs = WalletId <$> fromField f mbs

instance ToField WalletId where
  toField = toField . unWalletId

data Wallet = Wallet
  { walletId        :: !WalletId
  , walletUserId    :: !UUID
  , walletBalance   :: !Double
  , walletCreatedAt :: !UTCTime
  , walletUpdatedAt :: !UTCTime
  }

instance FromRow Wallet where
  fromRow = Wallet <$> field <*> field <*> field <*> field <*> field

data WalletResponse = WalletResponse
  { wrespId      :: !UUID
  , wrespBalance :: !Double
  }

instance ToJSON WalletResponse where
  toJSON w = object
    [ "id"      .= wrespId w
    , "balance" .= wrespBalance w
    ]

toWalletResponse :: Wallet -> WalletResponse
toWalletResponse w = WalletResponse
  (unWalletId $ walletId w)
  (walletBalance w)

data DepositRequest = DepositRequest
  { depAmount :: !Double
  }

instance FromJSON DepositRequest where
  parseJSON = withObject "DepositRequest" $ \o ->
    DepositRequest <$> o .: "amount"

data WithdrawRequest = WithdrawRequest
  { witAmount :: !Double
  }

instance FromJSON WithdrawRequest where
  parseJSON = withObject "WithdrawRequest" $ \o ->
    WithdrawRequest <$> o .: "amount"
