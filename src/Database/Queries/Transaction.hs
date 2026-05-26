{-# LANGUAGE OverloadedStrings #-}

module Database.Queries.Transaction where

import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple (Connection, Only(..), query, query_, execute)

import Models.Transaction (Transaction(..), TransactionId(..), TransactionType)

listTransactions :: Connection -> Maybe UUID -> Maybe Int -> Maybe Int -> IO [Transaction]
listTransactions conn mWalletId mLimit mOffset = do
  let limit  = fromMaybe 50 mLimit
      offset = fromMaybe 0  mOffset
  case mWalletId of
    Just wid -> query conn
      "SELECT id, wallet_id, type, amount, description, created_at FROM transactions WHERE wallet_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?"
      (wid, limit, offset)
    Nothing -> query conn
      "SELECT id, wallet_id, type, amount, description, created_at FROM transactions ORDER BY created_at DESC LIMIT ? OFFSET ?"
      (limit, offset)

findTransactionById :: Connection -> UUID -> IO (Maybe Transaction)
findTransactionById conn tid = do
  txns <- query conn
    "SELECT id, wallet_id, type, amount, description, created_at FROM transactions WHERE id = ?"
    (Only tid)
  pure $ case txns of
    (t:_) -> Just t
    []    -> Nothing

insertTransaction :: Connection -> Transaction -> IO ()
insertTransaction conn txn = execute conn
  "INSERT INTO transactions (id, wallet_id, type, amount, description) VALUES (?, ?, ?, ?, ?)"
  (txnId txn, txnWalletId txn, txnType txn, txnAmount txn, txnDescription txn)
