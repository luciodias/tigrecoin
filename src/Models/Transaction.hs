{-# LANGUAGE OverloadedStrings #-}

module Models.Transaction where

import Data.Aeson (ToJSON, (.=), object)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromField (FromField(..), returnError, ResultError(..))
import Database.PostgreSQL.Simple.FromRow (FromRow, field)
import Database.PostgreSQL.Simple.ToField (ToField(..), Action(Plain))
import Database.PostgreSQL.Simple.Types (PGArray(..))

import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

newtype TransactionId = TransactionId { unTransactionId :: UUID }

instance FromField TransactionId where
  fromField f mbs = TransactionId <$> fromField f mbs

instance ToField TransactionId where
  toField = toField . unTransactionId

data TransactionType
  = Deposit
  | Withdrawal
  | Bet
  | Win
  | Fee

instance FromField TransactionType where
  fromField f mbs = case mbs of
    Nothing -> returnError UnexpectedNull f ""
    Just bs -> case TE.decodeUtf8' bs of
      Left _  -> returnError ConversionFailed f "Invalid UTF-8"
      Right t -> case t of
        "deposit"    -> pure Deposit
        "withdrawal" -> pure Withdrawal
        "bet"        -> pure Bet
        "win"        -> pure Win
        "fee"        -> pure Fee
        _            -> returnError ConversionFailed f ("Unknown type: " <> T.unpack t)

instance ToField TransactionType where
  toField t = Plain $ case t of
    Deposit    -> "deposit"
    Withdrawal -> "withdrawal"
    Bet        -> "bet"
    Win        -> "win"
    Fee        -> "fee"

data Transaction = Transaction
  { txnId          :: !TransactionId
  , txnWalletId    :: !UUID
  , txnType        :: !TransactionType
  , txnAmount      :: !Double
  , txnDescription :: !Text
  , txnCreatedAt   :: !UTCTime
  }

instance FromRow Transaction where
  fromRow = Transaction <$> field <*> field <*> field <*> field <*> field <*> field

data TransactionResponse = TransactionResponse
  { trespId          :: !UUID
  , trespWalletId    :: !UUID
  , trespType        :: !Text
  , trespAmount      :: !Double
  , trespDescription :: !Text
  , trespCreatedAt   :: !UTCTime
  }

instance ToJSON TransactionResponse where
  toJSON t = object
    [ "id"          .= trespId t
    , "wallet_id"   .= trespWalletId t
    , "type"        .= trespType t
    , "amount"      .= trespAmount t
    , "description" .= trespDescription t
    , "created_at"  .= trespCreatedAt t
    ]

toTransactionResponse :: Transaction -> TransactionResponse
toTransactionResponse t = TransactionResponse
  (unTransactionId $ txnId t)
  (txnWalletId t)
  (showTxnType $ txnType t)
  (txnAmount t)
  (txnDescription t)
  (txnCreatedAt t)

showTxnType :: TransactionType -> Text
showTxnType Deposit    = "deposit"
showTxnType Withdrawal = "withdrawal"
showTxnType Bet        = "bet"
showTxnType Win        = "win"
showTxnType Fee        = "fee"
